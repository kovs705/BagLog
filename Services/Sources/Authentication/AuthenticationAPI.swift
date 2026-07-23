import Foundation

public actor AuthenticationAPI: AuthenticationAPIProviding {
    public static let maximumResponseSize = 64 * 1_024

    private let baseURL: URL?
    private let session: URLSession
    private let redirectDelegate: AuthenticationRedirectDelegate

    public init(
        baseURL: URL?,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
        self.baseURL = Self.validatedBaseURL(baseURL)
        let redirectDelegate = AuthenticationRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    public func signIn(identityToken: String) async throws -> AuthenticationSession {
        guard !identityToken.isEmpty else {
            throw AuthenticationError.missingIdentityToken
        }

        let body = try encodedBody(["identity_token": identityToken])
        let request = try makeRequest(
            path: "v1/auth/google/sign-in",
            body: body
        )
        return try await tokenSession(for: request)
    }

    public func refresh(refreshToken: String) async throws -> AuthenticationSession {
        guard !refreshToken.isEmpty else {
            throw AuthenticationError.rejected
        }

        let body = try encodedBody(["refresh_token": refreshToken])
        let request = try makeRequest(path: "v1/auth/refresh", body: body)
        return try await tokenSession(for: request)
    }

    public func logout(accessToken: String) async throws {
        guard !accessToken.isEmpty else {
            throw AuthenticationError.rejected
        }

        var request = try makeRequest(path: "v1/auth/logout", body: nil)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await response(for: request)
        guard response.statusCode == 204 else {
            throw mappedError(for: response.statusCode)
        }
    }

    private func tokenSession(for request: URLRequest) async throws -> AuthenticationSession {
        let (data, response) = try await response(for: request)
        guard response.statusCode == 200 || response.statusCode == 201 else {
            throw mappedError(for: response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(decoder)
        }

        let authenticationSession: AuthenticationSession
        do {
            authenticationSession = try decoder.decode(AuthenticationSession.self, from: data)
        } catch {
            throw AuthenticationError.unexpectedResponse
        }

        guard !authenticationSession.accessToken.isEmpty,
              !authenticationSession.refreshToken.isEmpty,
              authenticationSession.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame else {
            throw AuthenticationError.unexpectedResponse
        }

        return authenticationSession
    }

    private func response(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw AuthenticationError.cancelled
        } catch let error as URLError {
            throw Self.mappedTransportError(error)
        } catch {
            throw AuthenticationError.serviceUnavailable
        }

        guard data.count <= Self.maximumResponseSize else {
            throw AuthenticationError.responseTooLarge
        }
        guard let response = response as? HTTPURLResponse else {
            throw AuthenticationError.unexpectedResponse
        }
        return (data, response)
    }

    private func makeRequest(path: String, body: Data?) throws -> URLRequest {
        guard let baseURL else {
            throw AuthenticationError.configuration
        }

        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func encodedBody(_ value: [String: String]) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw AuthenticationError.invalidRequest
        }
    }

    private func mappedError(for statusCode: Int) -> AuthenticationError {
        switch statusCode {
        case 400: .invalidRequest
        case 401: .rejected
        case 429: .rateLimited
        case 503: .serviceUnavailable
        default: .unexpectedResponse
        }
    }

    private static func mappedTransportError(_ error: URLError) -> AuthenticationError {
        switch error.code {
        case .cancelled: .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            .networkUnavailable
        case .timedOut: .timedOut
        default: .serviceUnavailable
        }
    }

    private static func validatedBaseURL(_ url: URL?) -> URL? {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { return nil }
        return url
    }

    private static func decodeISO8601Date(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value) {
            return date
        }
        throw AuthenticationError.unexpectedResponse
    }
}
