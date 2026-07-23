import Foundation
import Services

@MainActor
final class TestGoogleIdentityProvider: GoogleIdentityProviding {
    private let token: String?
    private let error: Error?
    private let delay: Duration?
    private(set) var identityTokenCallCount = 0
    private(set) var signOutCallCount = 0

    init(
        token: String? = "google-id-token",
        error: Error? = nil,
        delay: Duration? = nil
    ) {
        self.token = token
        self.error = error
        self.delay = delay
    }

    func identityToken() async throws -> String {
        identityTokenCallCount += 1
        if let delay {
            try await Task.sleep(for: delay)
        }
        if let error {
            throw error
        }
        guard let token else {
            throw AuthenticationError.missingIdentityToken
        }
        return token
    }

    func signOut() {
        signOutCallCount += 1
    }

    func handle(_ url: URL) -> Bool {
        false
    }
}
