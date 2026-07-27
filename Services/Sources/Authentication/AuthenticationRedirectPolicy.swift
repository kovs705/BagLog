import Foundation

public enum AuthenticationRedirectPolicy {
    public static func allowsRedirect(from sourceURL: URL, to destinationURL: URL) -> Bool {
        guard sourceURL.scheme?.lowercased() == "https",
              destinationURL.scheme?.lowercased() == "https" else {
            return false
        }
        return normalizedOrigin(for: sourceURL) == normalizedOrigin(for: destinationURL)
    }

    private static func normalizedOrigin(for url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased() else { return nil }

        let port = url.port ?? defaultPort(for: scheme)
        guard let port else { return nil }
        return "\(scheme)://\(host):\(port)"
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "https": 443
        case "http": 80
        default: nil
        }
    }
}
