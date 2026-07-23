import Foundation

struct AuthenticationConfiguration {
    let apiBaseURL: URL?

    init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "BAGLOG_API_BASE_URL") as? String
        let url = value.flatMap(URL.init(string:))
        if url?.host?.hasSuffix(".invalid") == true {
            apiBaseURL = nil
        } else {
            apiBaseURL = url
        }
    }
}
