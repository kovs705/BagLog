import Foundation

@MainActor
public protocol GoogleIdentityProviding: Sendable {
    func identityToken() async throws -> String
    func signOut()
    func handle(_ url: URL) -> Bool
}
