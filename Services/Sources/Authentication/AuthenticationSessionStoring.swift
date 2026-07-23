public protocol AuthenticationSessionStoring: Sendable {
    func load() async throws -> AuthenticationSession?
    func save(_ session: AuthenticationSession) async throws
    func clear() async throws
}
