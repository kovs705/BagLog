#if DEBUG
enum AuthenticationUITestScenario {
    case signedOut
    case success
    case retry
    case signedIn

    init(arguments: [String]) {
        if arguments.contains("--auth-ui-test-signed-in") {
            self = .signedIn
        } else if arguments.contains("--auth-ui-test-retry") {
            self = .retry
        } else if arguments.contains("--auth-ui-test-success") {
            self = .success
        } else {
            self = .signedOut
        }
    }
}
#endif
