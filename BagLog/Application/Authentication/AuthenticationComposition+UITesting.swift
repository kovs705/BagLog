#if DEBUG
import Services

extension AuthenticationComposition {
    static func makeUITestStore(arguments: [String]) -> AuthenticationStore {
        let scenario = AuthenticationUITestScenario(arguments: arguments)
        let storedSession: AuthenticationSession? = scenario == .signedIn ? .uiTestSession : nil
        let sessionController = BagLogSessionController(
            api: AuthenticationUITestAPI(scenario: scenario),
            storage: AuthenticationUITestSessionStorage(session: storedSession),
            clock: SystemAuthenticationClock()
        )
        return AuthenticationStore(
            dependencies: AuthenticationDependencies(
                identityProvider: AuthenticationUITestIdentityProvider(),
                sessionController: sessionController
            )
        )
    }
}
#endif
