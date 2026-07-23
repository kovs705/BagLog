import Foundation

/// URLSession owns and may call this delegate concurrently. It is safe to mark Sendable because
/// it has no stored mutable state and delegates every decision to a pure value operation.
final class AuthenticationRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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
