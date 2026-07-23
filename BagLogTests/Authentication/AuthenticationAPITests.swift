import Foundation
import Services
import Testing

@Suite("Authentication API", .serialized)
struct AuthenticationAPITests {
    @Test("Google identity token is exchanged with the documented request")
    func signInRequest() async throws {
        TestURLProtocol.configure(data: tokenResponseData)
        let api = makeAPI()

        let session = try await api.signIn(identityToken: "secret-google-token")
        let request = try #require(TestURLProtocol.request())
        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/auth/google/sign-in")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(json == ["identity_token": "secret-google-token"])
        #expect(session.accessToken == "baglog-access-token")
        #expect(session.refreshToken == "baglog-refresh-token")
    }

    @Test("Refresh rotates the credential using the documented request")
    func refreshRequest() async throws {
        TestURLProtocol.configure(data: tokenResponseData)
        let api = makeAPI()

        _ = try await api.refresh(refreshToken: "old-refresh-token")
        let request = try #require(TestURLProtocol.request())
        let body = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )

        #expect(request.url?.path == "/v1/auth/refresh")
        #expect(json == ["refresh_token": "old-refresh-token"])
    }

    @Test("Logout sends only the BagLog bearer credential")
    func logoutRequest() async throws {
        TestURLProtocol.configure(statusCode: 204)
        let api = makeAPI()

        try await api.logout(accessToken: "secret-access-token")
        let request = try #require(TestURLProtocol.request())

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/auth/logout")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-access-token")
        #expect(request.httpBody == nil)
    }

    @Test("Stable backend statuses map to safe domain errors")
    func backendErrorMapping() async throws {
        let mappings: [(Int, AuthenticationError)] = [
            (400, .invalidRequest),
            (401, .rejected),
            (429, .rateLimited),
            (503, .serviceUnavailable)
        ]

        for (statusCode, expectedError) in mappings {
            TestURLProtocol.configure(statusCode: statusCode)
            let api = makeAPI()
            await #expect(throws: expectedError) {
                try await api.signIn(identityToken: "secret-google-token")
            }
        }
    }

    @Test("Offline and timeout failures map without leaking transport details")
    func transportErrorMapping() async throws {
        TestURLProtocol.configure(errorCode: .notConnectedToInternet)
        await #expect(throws: AuthenticationError.networkUnavailable) {
            try await makeAPI().signIn(identityToken: "secret-google-token")
        }

        TestURLProtocol.configure(errorCode: .timedOut)
        await #expect(throws: AuthenticationError.timedOut) {
            try await makeAPI().signIn(identityToken: "secret-google-token")
        }
    }

    @Test("Malformed and oversized responses are rejected before decoding")
    func responseValidation() async throws {
        TestURLProtocol.configure(data: Data("not-json".utf8))
        await #expect(throws: AuthenticationError.unexpectedResponse) {
            try await makeAPI().signIn(identityToken: "secret-google-token")
        }

        TestURLProtocol.configure(
            data: Data(repeating: 0, count: AuthenticationAPI.maximumResponseSize + 1)
        )
        await #expect(throws: AuthenticationError.responseTooLarge) {
            try await makeAPI().signIn(identityToken: "secret-google-token")
        }
    }

    @Test("Missing identity tokens fail locally without opening the network")
    func missingIdentityToken() async throws {
        TestURLProtocol.configure(data: tokenResponseData)
        await #expect(throws: AuthenticationError.missingIdentityToken) {
            try await makeAPI().signIn(identityToken: "")
        }
        #expect(TestURLProtocol.request() == nil)
    }

    @Test("Authentication redirects remain on the configured origin")
    func redirectPolicy() throws {
        let source = try #require(URL(string: "https://api.example.com/v1/auth/refresh"))
        let sameOrigin = try #require(URL(string: "https://api.example.com/v1/auth/refresh-2"))
        let otherHost = try #require(URL(string: "https://attacker.example/v1/auth/refresh"))
        let downgraded = try #require(URL(string: "http://api.example.com/v1/auth/refresh"))

        #expect(AuthenticationRedirectPolicy.allowsRedirect(from: source, to: sameOrigin))
        #expect(!AuthenticationRedirectPolicy.allowsRedirect(from: source, to: otherHost))
        #expect(!AuthenticationRedirectPolicy.allowsRedirect(from: source, to: downgraded))
    }

    @Test("Authentication errors never describe secret values")
    func tokenRedaction() {
        let secret = "top-secret-refresh-token"
        for error in [
            AuthenticationError.invalidRequest,
            .rejected,
            .unexpectedResponse,
            .secureStorage
        ] {
            #expect(!error.description.contains(secret))
            #expect(!error.userMessage.contains(secret))
        }
    }

    private func makeAPI() -> AuthenticationAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return AuthenticationAPI(
            baseURL: URL(string: "https://api.example.com"),
            configuration: configuration
        )
    }

    private var tokenResponseData: Data {
        Data(
            #"{"access_token":"baglog-access-token","access_expires_at":"2026-07-22T23:00:00Z","refresh_token":"baglog-refresh-token","refresh_expires_at":"2026-08-22T23:00:00.123Z","token_type":"Bearer"}"#.utf8
        )
    }
}
