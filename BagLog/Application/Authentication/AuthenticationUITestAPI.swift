#if DEBUG
import Foundation
import Services

actor AuthenticationUITestAPI: AuthenticationAPIProviding {
    private var failuresRemaining: Int

    init(scenario: AuthenticationUITestScenario) {
        failuresRemaining = scenario == .retry ? 1 : 0
    }

    func signIn(identityToken: String) async throws -> AuthenticationSession {
        try await Task.sleep(for: .seconds(2))
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw AuthenticationError.networkUnavailable
        }
        return .uiTestSession
    }

    func refresh(refreshToken: String) -> AuthenticationSession {
        .uiTestSession
    }

    func logout(accessToken: String) {}
}
#endif
