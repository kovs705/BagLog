import Foundation
import Services

@MainActor
enum AuthenticationComposition {
    static func make(
        processInfo: ProcessInfo = .processInfo,
        bundle: Bundle = .main
    ) -> AuthenticationStore {
#if DEBUG
        if processInfo.arguments.contains("--ui-testing") {
            return makeUITestStore(arguments: processInfo.arguments)
        }
#endif

        let configuration = AuthenticationConfiguration(bundle: bundle)
        let api = AuthenticationAPI(baseURL: configuration.apiBaseURL)
        let sessionController = BagLogSessionController(
            api: api,
            storage: KeychainSessionVault(),
            clock: SystemAuthenticationClock()
        )
        return AuthenticationStore(
            dependencies: AuthenticationDependencies(
                identityProvider: GoogleIdentityProvider(bundle: bundle),
                sessionController: sessionController
            )
        )
    }
}
