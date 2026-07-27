public protocol BagLogAccessTokenProviding: Sendable {
    func validAccessToken() async throws -> String
    func refreshAccessToken() async throws -> String
}
