import Foundation
import Services
import Testing

@Suite("Keychain session vault", .serialized)
struct KeychainSessionVaultTests {
    @Test("A rotated pair atomically replaces the previous Keychain value")
    func atomicReplacement() async throws {
        let vault = KeychainSessionVault(
            service: "com.CodingKovs.BagLog.tests.\(UUID().uuidString)",
            account: "session"
        )
        let firstSession = makeSession(accessToken: "first-access", refreshToken: "first-refresh")
        let rotatedSession = makeSession(accessToken: "second-access", refreshToken: "second-refresh")

        try await vault.clear()
        try await vault.save(firstSession)
        #expect(try await vault.load() == firstSession)

        try await vault.save(rotatedSession)
        #expect(try await vault.load() == rotatedSession)

        try await vault.clear()
        #expect(try await vault.load() == nil)
    }

    private func makeSession(
        accessToken: String,
        refreshToken: String
    ) -> AuthenticationSession {
        AuthenticationSession(
            accessToken: accessToken,
            accessExpiresAt: .now.addingTimeInterval(600),
            refreshToken: refreshToken,
            refreshExpiresAt: .now.addingTimeInterval(86_400),
            tokenType: "Bearer"
        )
    }
}
