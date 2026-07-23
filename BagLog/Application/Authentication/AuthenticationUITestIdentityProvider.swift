#if DEBUG
import Foundation
import Services

@MainActor
final class AuthenticationUITestIdentityProvider: GoogleIdentityProviding {
    func identityToken() async throws -> String {
        "ui-test-google-identity-token"
    }

    func signOut() {}

    func handle(_ url: URL) -> Bool {
        false
    }
}
#endif
