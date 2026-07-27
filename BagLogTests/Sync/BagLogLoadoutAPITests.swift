import Foundation
import Persistence
import Services
import Testing

@Suite("Private loadout API", .serialized)
struct BagLogLoadoutAPITests {
    private let loadoutID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1)
    )
    private let itemID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2)
    )
    private let linkID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3)
    )

    @Test("Create uses stable IDs, canonical headers, and explicit null optionals")
    func createRequest() async throws {
        TestURLProtocol.configure(
            statusCode: 201,
            data: aggregateData(revision: 1),
            headers: [
                "ETag": "\"1\"",
                "Idempotency-Replayed": "true"
            ]
        )
        let tokenProvider = TestAccessTokenProvider()
        let api = makeAPI(tokenProvider: tokenProvider)
        let body = try await api.encodeMutationBody(for: projection())
        let idempotencyKey = UUID()

        let response = try await api.performMutation(
            attempt(
                operation: .create,
                idempotencyKey: idempotencyKey,
                body: body
            )
        )
        let request = try #require(TestURLProtocol.request())
        let requestBody = try #require(request.httpBody)
        let json = try #require(
            JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        )
        let items = try #require(json["items"] as? [[String: Any]])
        let links = try #require(items[0]["links"] as? [[String: Any]])

        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/loadouts")
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer access-token"
        )
        #expect(
            request.value(forHTTPHeaderField: "Idempotency-Key")
                == idempotencyKey.uuidString.lowercased()
        )
        #expect(request.value(forHTTPHeaderField: "If-Match") == nil)
        #expect(items[0]["category"] is NSNull)
        #expect(items[0]["brand"] is NSNull)
        #expect(items[0]["model"] is NSNull)
        #expect(items[0]["notes"] is NSNull)
        #expect(links[0]["label"] is NSNull)
        #expect(response.wasReplayed)
    }

    @Test("Replace and delete send strong revisions with exact stored inputs")
    func revisionedMutations() async throws {
        let tokenProvider = TestAccessTokenProvider()
        let api = makeAPI(tokenProvider: tokenProvider)
        let body = try await api.encodeMutationBody(for: projection())

        TestURLProtocol.configure(
            statusCode: 200,
            data: aggregateData(revision: 4),
            headers: ["ETag": "\"4\""]
        )
        _ = try await api.performMutation(
            attempt(
                operation: .replace,
                expectedRevision: 3,
                body: body
            )
        )
        let replace = try #require(TestURLProtocol.request())
        #expect(replace.httpMethod == "PUT")
        #expect(replace.url?.path == "/v1/loadouts/\(loadoutID.uuidString.lowercased())")
        #expect(replace.value(forHTTPHeaderField: "If-Match") == "\"3\"")
        #expect(replace.httpBody == body)

        TestURLProtocol.configure(
            statusCode: 200,
            data: tombstoneData(revision: 5),
            headers: ["ETag": "\"5\""]
        )
        _ = try await api.performMutation(
            attempt(operation: .delete, expectedRevision: 4, body: nil)
        )
        let delete = try #require(TestURLProtocol.request())
        #expect(delete.httpMethod == "DELETE")
        #expect(delete.value(forHTTPHeaderField: "If-Match") == "\"4\"")
        #expect(delete.httpBody == nil)
    }

    @Test("One invalid-token response forces one refresh and one retry")
    func refreshesOnceAfterUnauthorized() async throws {
        TestURLProtocol.configure(
            stubs: [
                TestURLProtocol.Stub(
                    statusCode: 401,
                    data: errorData(code: "invalid_token")
                ),
                TestURLProtocol.Stub(
                    statusCode: 201,
                    data: aggregateData(revision: 1),
                    headers: ["ETag": "\"1\""]
                )
            ]
        )
        let tokenProvider = TestAccessTokenProvider()
        let api = makeAPI(tokenProvider: tokenProvider)
        let body = try await api.encodeMutationBody(for: projection())

        _ = try await api.performMutation(
            attempt(operation: .create, body: body)
        )

        let requests = TestURLProtocol.requests()
        #expect(requests.count == 2)
        #expect(
            requests[0].value(forHTTPHeaderField: "Authorization")
                == "Bearer access-token"
        )
        #expect(
            requests[1].value(forHTTPHeaderField: "Authorization")
                == "Bearer refreshed-token"
        )
        #expect(await tokenProvider.refreshCallCount == 1)
    }

    @Test("A second unauthorized response stops after one forced refresh")
    func doesNotLoopAfterUnauthorizedRetry() async throws {
        TestURLProtocol.configure(
            stubs: [
                TestURLProtocol.Stub(
                    statusCode: 401,
                    data: errorData(code: "invalid_token")
                ),
                TestURLProtocol.Stub(
                    statusCode: 401,
                    data: errorData(code: "invalid_token")
                )
            ]
        )
        let tokenProvider = TestAccessTokenProvider()
        let api = makeAPI(tokenProvider: tokenProvider)
        let body = try await api.encodeMutationBody(for: projection())

        await #expect(throws: BagLogSyncError.invalidToken) {
            _ = try await api.performMutation(
                attempt(operation: .create, body: body)
            )
        }

        #expect(TestURLProtocol.requests().count == 2)
        #expect(await tokenProvider.refreshCallCount == 1)
    }

    @Test("Response revisions must match their strong ETag")
    func rejectsRevisionETagMismatch() async throws {
        TestURLProtocol.configure(
            data: aggregateData(revision: 2),
            headers: ["ETag": "\"3\""]
        )
        let api = makeAPI(tokenProvider: TestAccessTokenProvider())

        await #expect(throws: BagLogSyncError.unexpectedResponse) {
            _ = try await api.loadout(id: loadoutID)
        }
    }

    @Test("Invalid local projections fail before opening the network")
    func rejectsInvalidLocalProjection() async throws {
        TestURLProtocol.configure()
        let api = makeAPI(tokenProvider: TestAccessTokenProvider())
        let invalid = LoadoutSyncProjection(
            id: loadoutID,
            title: " ",
            summary: "",
            category: "camera",
            items: [],
            tags: []
        )

        await #expect(throws: BagLogSyncError.invalidRequest) {
            _ = try await api.encodeMutationBody(for: invalid)
        }
        #expect(TestURLProtocol.requests().isEmpty)
    }

    @Test("Bootstrap and changes enforce fixed, advancing cursors")
    func pageValidation() async throws {
        let tokenProvider = TestAccessTokenProvider()
        let api = makeAPI(tokenProvider: tokenProvider)
        let after = loadoutID
        TestURLProtocol.configure(
            data: Data(
                """
                {
                  "loadouts": [\(aggregateJSON(revision: 1))],
                  "cursor": 7,
                  "next_after": "\(after.uuidString.lowercased())",
                  "has_more": true
                }
                """.utf8
            )
        )

        let bootstrap = try await api.bootstrap(cursor: nil, after: nil)
        let request = try #require(TestURLProtocol.request())
        let requestURL = try #require(request.url)
        let components = try #require(
            URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        )
        #expect(bootstrap.cursor == 7)
        #expect(bootstrap.nextAfter == loadoutID)
        #expect(
            components.queryItems
                == [URLQueryItem(name: "limit", value: "20")]
        )

        TestURLProtocol.configure(
            data: Data(
                """
                {
                  "changes": [{
                    "cursor": 8,
                    "resource_id": "\(loadoutID.uuidString.lowercased())",
                    "operation": "delete",
                    "revision": 2,
                    "changed_at": "2026-07-26T00:00:01Z",
                    "loadout": null
                  }],
                  "next_cursor": 8,
                  "has_more": false
                }
                """.utf8
            )
        )
        let changes = try await api.changes(cursor: 7)
        #expect(changes.nextCursor == 8)
        guard case .delete = changes.changes[0].payload else {
            Issue.record("Expected a tombstone")
            return
        }
    }

    @Test("Stable server failures map safely and strict shapes reject extra fields")
    func safeErrorsAndStrictShapes() async throws {
        let api = makeAPI(tokenProvider: TestAccessTokenProvider())
        let mappings: [(Int, String, BagLogSyncError)] = [
            (409, "profile_required", .profileRequired),
            (409, "mutation_in_progress", .mutationInProgress(retryAfter: 12)),
            (409, "loadout_conflict", .loadoutConflict),
            (412, "revision_mismatch", .revisionMismatch),
            (428, "revision_required", .revisionRequired),
            (400, "invalid_cursor", .invalidCursor),
            (410, "cursor_expired", .cursorExpired),
            (500, "internal_error", .internalError)
        ]

        for (status, code, expected) in mappings {
            TestURLProtocol.configure(
                statusCode: status,
                data: errorData(code: code),
                headers: status == 409 && code == "mutation_in_progress"
                    ? ["Retry-After": "12"]
                    : [:]
            )
            await #expect(throws: expected) {
                _ = try await api.changes(cursor: 1)
            }
        }

        let malformed = aggregateJSON(revision: 1)
            .replacingOccurrences(
                of: #""updated_at": "2026-07-26T00:00:00Z""#,
                with: #""updated_at": "2026-07-26T00:00:00Z", "private": "leak""#
            )
        TestURLProtocol.configure(
            statusCode: 200,
            data: Data(malformed.utf8),
            headers: ["ETag": "\"1\""]
        )
        await #expect(throws: BagLogSyncError.unexpectedResponse) {
            _ = try await api.loadout(id: loadoutID)
        }
        #expect(!BagLogSyncError.invalidToken.description.contains("secret"))
    }

    private func makeAPI(
        tokenProvider: TestAccessTokenProvider
    ) -> BagLogLoadoutAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        return BagLogLoadoutAPI(
            baseURL: URL(string: "https://api.example.com"),
            accessTokenProvider: tokenProvider,
            configuration: configuration
        )
    }

    private func projection() -> LoadoutSyncProjection {
        LoadoutSyncProjection(
            id: loadoutID,
            title: "Camera kit",
            summary: "",
            category: "camera",
            items: [
                LoadoutSyncItem(
                    id: itemID,
                    title: "Camera",
                    category: nil,
                    brand: nil,
                    model: nil,
                    notes: nil,
                    quantity: 1,
                    isEssential: true,
                    links: [
                        LoadoutSyncLink(
                            id: linkID,
                            urlString: "https://example.com/camera",
                            label: nil
                        )
                    ]
                )
            ],
            tags: ["camera"]
        )
    }

    private func attempt(
        operation: LoadoutMutationOperation,
        idempotencyKey: UUID = UUID(),
        expectedRevision: Int64? = nil,
        body: Data?
    ) -> LoadoutMutationAttemptValue {
        LoadoutMutationAttemptValue(
            idempotencyKey: idempotencyKey,
            pendingChangeID: UUID(),
            scopeID: UUID(),
            loadoutID: loadoutID,
            operation: operation,
            expectedRevision: expectedRevision,
            encodedBody: body,
            localGeneration: 1,
            state: .ready,
            firstAttemptedAt: nil,
            retryNotBefore: nil,
            attemptCount: 0
        )
    }

    private func aggregateData(revision: Int64) -> Data {
        Data(aggregateJSON(revision: revision).utf8)
    }

    private func aggregateJSON(revision: Int64) -> String {
        """
        {
          "id": "\(loadoutID.uuidString.lowercased())",
          "title": "Camera kit",
          "summary": "",
          "category": "camera",
          "items": [{
            "id": "\(itemID.uuidString.lowercased())",
            "title": "Camera",
            "category": null,
            "brand": null,
            "model": null,
            "notes": null,
            "quantity": 1,
            "is_essential": true,
            "links": [{
              "id": "\(linkID.uuidString.lowercased())",
              "url": "https://example.com/camera",
              "label": null
            }]
          }],
          "tags": ["camera"],
          "revision": \(revision),
          "created_at": "2026-07-26T00:00:00Z",
          "updated_at": "2026-07-26T00:00:00Z"
        }
        """
    }

    private func tombstoneData(revision: Int64) -> Data {
        Data(
            """
            {
              "id": "\(loadoutID.uuidString.lowercased())",
              "revision": \(revision),
              "deleted_at": "2026-07-26T00:00:00Z"
            }
            """.utf8
        )
    }

    private func errorData(code: String) -> Data {
        Data(
            """
            {
              "code": "\(code)",
              "message": "safe",
              "trace_id": "0123456789abcdef0123456789abcdef"
            }
            """.utf8
        )
    }
}

private actor TestAccessTokenProvider: BagLogAccessTokenProviding {
    private(set) var refreshCallCount = 0

    func validAccessToken() -> String {
        "access-token"
    }

    func refreshAccessToken() -> String {
        refreshCallCount += 1
        return "refreshed-token"
    }
}
