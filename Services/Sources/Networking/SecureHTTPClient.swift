import Foundation

enum SecureHTTPClientError: Error, Sendable {
    case cancelled
    case configuration
    case networkUnavailable
    case responseTooLarge
    case serviceUnavailable
    case timedOut
    case unexpectedResponse
}

struct SecureHTTPResponse: Sendable {
    let data: Data
    let response: HTTPURLResponse
}

actor SecureHTTPClient {
    private let baseURL: URL?
    private let session: URLSession
    private let redirectDelegate: SecureRedirectDelegate

    init(
        baseURL: URL?,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
        self.baseURL = Self.validatedBaseURL(baseURL)
        let redirectDelegate = SecureRedirectDelegate()
        self.redirectDelegate = redirectDelegate
        session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    func makeRequest(
        pathComponents: [String],
        queryItems: [URLQueryItem] = [],
        method: String,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) throws -> URLRequest {
        guard let baseURL else {
            throw SecureHTTPClientError.configuration
        }
        let url = try requestURL(
            baseURL: baseURL,
            pathComponents: pathComponents,
            queryItems: queryItems
        )
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeout
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    func response(
        for request: URLRequest,
        maximumResponseSize: Int
    ) async throws -> SecureHTTPResponse {
        try Task.checkCancellation()
        let values = try await data(for: request)
        guard values.data.count <= maximumResponseSize else {
            throw SecureHTTPClientError.responseTooLarge
        }
        guard let response = values.response as? HTTPURLResponse else {
            throw SecureHTTPClientError.unexpectedResponse
        }
        return SecureHTTPResponse(data: values.data, response: response)
    }

    private func data(
        for request: URLRequest
    ) async throws -> (data: Data, response: URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw SecureHTTPClientError.cancelled
        } catch let error as URLError {
            throw Self.mappedTransportError(error)
        } catch {
            throw SecureHTTPClientError.serviceUnavailable
        }
    }

    private func requestURL(
        baseURL: URL,
        pathComponents: [String],
        queryItems: [URLQueryItem]
    ) throws -> URL {
        var url = baseURL
        for component in pathComponents {
            guard !component.isEmpty,
                  !component.contains("/"),
                  component != ".",
                  component != ".." else {
                throw SecureHTTPClientError.configuration
            }
            url.append(path: component)
        }
        guard !queryItems.isEmpty else {
            return url
        }
        guard var components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            throw SecureHTTPClientError.configuration
        }
        components.queryItems = queryItems
        guard let queryURL = components.url else {
            throw SecureHTTPClientError.configuration
        }
        return queryURL
    }

    private static func validatedBaseURL(_ url: URL?) -> URL? {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/" else {
            return nil
        }
        return url
    }

    private static func mappedTransportError(
        _ error: URLError
    ) -> SecureHTTPClientError {
        switch error.code {
        case .cancelled:
            .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            .networkUnavailable
        case .timedOut:
            .timedOut
        default:
            .serviceUnavailable
        }
    }
}

final class SecureRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let sourceURL = response.url,
              let destinationURL = request.url,
              AuthenticationRedirectPolicy.allowsRedirect(
                from: sourceURL,
                to: destinationURL
              ) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
