#if DEBUG
import Services

extension AuthenticationComposition {
    static func makeUITestStore(arguments: [String]) -> AuthenticationStore {
        let scenario = AuthenticationUITestScenario(arguments: arguments)
        let storedSession: AuthenticationSession? = scenario == .signedIn ? .uiTestSession : nil
        return AuthenticationStore(
            dependencies: AuthenticationDependencies(
                identityProvider: AuthenticationUITestIdentityProvider(),
                api: AuthenticationUITestAPI(scenario: scenario),
                sessionStorage: AuthenticationUITestSessionStorage(session: storedSession),
                clock: SystemAuthenticationClock()
            )
        )
    }
}
#endif
