import Foundation

public actor AuthenticationAPI: AuthenticationAPIProviding {
    public static let maximumResponseSize = 64 * 1_024

    private let client: SecureHTTPClient

    public init(
        baseURL: URL?,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
        client = SecureHTTPClient(
            baseURL: baseURL,
            configuration: configuration
        )
    }

    public func signIn(identityToken: String) async throws -> AuthenticationSession {
        guard !identityToken.isEmpty else {
            throw AuthenticationError.missingIdentityToken
        }

        let body = try encodedBody(["identity_token": identityToken])
        let request = try await makeRequest(
            pathComponents: ["v1", "auth", "google", "sign-in"],
            body: body
        )
        return try await tokenSession(for: request)
    }

    public func refresh(refreshToken: String) async throws -> AuthenticationSession {
        guard !refreshToken.isEmpty else {
            throw AuthenticationError.rejected
        }

        let body = try encodedBody(["refresh_token": refreshToken])
        let request = try await makeRequest(
            pathComponents: ["v1", "auth", "refresh"],
            body: body
        )
        return try await tokenSession(for: request)
    }

    public func logout(accessToken: String) async throws {
        guard !accessToken.isEmpty else {
            throw AuthenticationError.rejected
        }

        var request = try await makeRequest(
            pathComponents: ["v1", "auth", "logout"],
            body: nil
        )
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let response = try await response(for: request)
        guard response.response.statusCode == 204 else {
            throw mappedError(for: response.response.statusCode)
        }
    }

    private func tokenSession(for request: URLRequest) async throws -> AuthenticationSession {
        let response = try await response(for: request)
        guard response.response.statusCode == 200
                || response.response.statusCode == 201 else {
            throw mappedError(for: response.response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(decoder)
        }

        let authenticationSession: AuthenticationSession
        do {
            authenticationSession = try decoder.decode(
                AuthenticationSession.self,
                from: response.data
            )
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

    private func response(
        for request: URLRequest
    ) async throws -> SecureHTTPResponse {
        do {
            return try await client.response(
                for: request,
                maximumResponseSize: Self.maximumResponseSize
            )
        } catch let error as SecureHTTPClientError {
            throw mappedClientError(error)
        } catch {
            throw AuthenticationError.serviceUnavailable
        }
    }

    private func makeRequest(
        pathComponents: [String],
        body: Data?
    ) async throws -> URLRequest {
        var headers = ["Accept": "application/json"]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }
        do {
            return try await client.makeRequest(
                pathComponents: pathComponents,
                method: "POST",
                headers: headers,
                body: body
            )
        } catch {
            throw AuthenticationError.configuration
        }
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

    private func mappedClientError(
        _ error: SecureHTTPClientError
    ) -> AuthenticationError {
        switch error {
        case .cancelled:
            .cancelled
        case .configuration:
            .configuration
        case .networkUnavailable:
            .networkUnavailable
        case .responseTooLarge:
            .responseTooLarge
        case .serviceUnavailable:
            .serviceUnavailable
        case .timedOut:
            .timedOut
        case .unexpectedResponse:
            .unexpectedResponse
        }
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
