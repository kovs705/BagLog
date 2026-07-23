public protocol AuthenticationAPIProviding: Sendable {
    func signIn(identityToken: String) async throws -> AuthenticationSession
    func refresh(refreshToken: String) async throws -> AuthenticationSession
    func logout(accessToken: String) async throws
}
