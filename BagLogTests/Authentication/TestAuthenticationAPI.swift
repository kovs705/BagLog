import Foundation
import Services

actor TestAuthenticationAPI: AuthenticationAPIProviding {
    private let signInSession: AuthenticationSession
    private let refreshSession: AuthenticationSession
    private let signInError: Error?
    private let refreshError: Error?
    private let logoutError: Error?
    private let signInDelay: Duration?
    private var receivedIdentityTokens: [String] = []
    private var receivedRefreshTokens: [String] = []
    private var receivedLogoutTokens: [String] = []

    init(
        signInSession: AuthenticationSession,
        refreshSession: AuthenticationSession? = nil,
        signInError: Error? = nil,
        refreshError: Error? = nil,
        logoutError: Error? = nil,
        signInDelay: Duration? = nil
    ) {
        self.signInSession = signInSession
        self.refreshSession = refreshSession ?? signInSession
        self.signInError = signInError
        self.refreshError = refreshError
        self.logoutError = logoutError
        self.signInDelay = signInDelay
    }

    func signIn(identityToken: String) async throws -> AuthenticationSession {
        receivedIdentityTokens.append(identityToken)
        if let signInDelay {
            try await Task.sleep(for: signInDelay)
        }
        if let signInError {
            throw signInError
        }
        return signInSession
    }

    func refresh(refreshToken: String) throws -> AuthenticationSession {
        receivedRefreshTokens.append(refreshToken)
        if let refreshError {
            throw refreshError
        }
        return refreshSession
    }

    func logout(accessToken: String) throws {
        receivedLogoutTokens.append(accessToken)
        if let logoutError {
            throw logoutError
        }
    }

    func identityTokens() -> [String] {
        receivedIdentityTokens
    }

    func refreshTokens() -> [String] {
        receivedRefreshTokens
    }

    func logoutTokens() -> [String] {
        receivedLogoutTokens
    }
}
