import Foundation
import Persistence

public actor BagLogLoadoutAPI: BagLogLoadoutAPIProviding {
    public static let maximumAggregateResponseSize = 576 * 1_024
    public static let maximumPageResponseSize =
        20 * maximumAggregateResponseSize + 64 * 1_024
    public static let maximumProfileResponseSize = 64 * 1_024

    private let client: SecureHTTPClient
    private let accessTokenProvider: any BagLogAccessTokenProviding
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL?,
        accessTokenProvider: any BagLogAccessTokenProviding,
        configuration: URLSessionConfiguration = .ephemeral
    ) {
        client = SecureHTTPClient(
            baseURL: baseURL,
            configuration: configuration
        )
        self.accessTokenProvider = accessTokenProvider
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(decoder)
        }
        self.decoder = decoder
    }

    public func ownProfile() async throws -> BagLogRemoteProfile {
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumProfileResponseSize
        ) { token in
            try await self.request(
                path: ["v1", "profile"],
                method: "GET",
                token: token
            )
        }
        if response.response.statusCode == 404 {
            throw BagLogSyncError.profileNotFound
        }
        try requireStatus(200, response: response)
        try StrictSyncJSONValidator.validateProfile(response.data)
        let profile = try decode(ProfileDTO.self, from: response.data)
        try validateProfile(profile)
        try validateRevisionETag(response.response, revision: profile.revision)
        return BagLogRemoteProfile(id: profile.id, revision: profile.revision)
    }

    public func createOwnProfile(
        _ write: BagLogProfileWrite
    ) async throws -> BagLogRemoteProfile {
        try validateProfileWrite(write)
        let body = try encode(
            ProfileWriteDTO(
                handle: write.handle,
                displayName: write.displayName,
                bio: write.bio
            )
        )
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumProfileResponseSize
        ) { token in
            try await self.request(
                path: ["v1", "profile"],
                method: "POST",
                token: token,
                body: body
            )
        }
        if response.response.statusCode == 409 {
            throw BagLogSyncError.profileConflict
        }
        try requireStatus(201, response: response)
        try StrictSyncJSONValidator.validateProfile(response.data)
        let profile = try decode(ProfileDTO.self, from: response.data)
        try validateProfile(profile)
        try validateRevisionETag(response.response, revision: profile.revision)
        return BagLogRemoteProfile(id: profile.id, revision: profile.revision)
    }

    public func encodeMutationBody(
        for projection: LoadoutSyncProjection
    ) throws -> Data {
        do {
            try validateProjection(projection)
        } catch {
            throw BagLogSyncError.invalidRequest
        }
        let data = try encode(projection.transportDTO)
        guard data.count <= 512 * 1_024 else {
            throw BagLogSyncError.invalidRequest
        }
        return data
    }

    public func performMutation(
        _ attempt: LoadoutMutationAttemptValue
    ) async throws -> BagLogMutationResponse {
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumAggregateResponseSize
        ) { token in
            try await self.mutationRequest(attempt, token: token)
        }
        let expectedStatus = attempt.operation == .create ? 201 : 200
        try requireStatus(expectedStatus, response: response)
        let replayed = try idempotencyWasReplayed(response.response)

        switch attempt.operation {
        case .create, .replace:
            let aggregate = try decodedAggregate(
                from: response,
                expectedID: attempt.loadoutID
            )
            return BagLogMutationResponse(
                result: .aggregate(aggregate),
                wasReplayed: replayed
            )
        case .delete:
            let tombstone = try decodedTombstone(
                from: response,
                expectedID: attempt.loadoutID
            )
            return BagLogMutationResponse(
                result: .tombstone(tombstone),
                wasReplayed: replayed
            )
        }
    }

    public func loadout(id: UUID) async throws -> RemoteLoadoutAggregate {
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumAggregateResponseSize
        ) { token in
            try await self.request(
                path: ["v1", "loadouts", id.uuidString.lowercased()],
                method: "GET",
                token: token
            )
        }
        if response.response.statusCode == 404 {
            throw BagLogSyncError.loadoutNotFound
        }
        try requireStatus(200, response: response)
        return try decodedAggregate(from: response, expectedID: id)
    }

    public func bootstrap(
        cursor: Int64?,
        after: UUID?
    ) async throws -> BagLogBootstrapPage {
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumPageResponseSize
        ) { token in
            try await self.request(
                path: ["v1", "sync", "bootstrap"],
                queryItems: self.bootstrapQuery(cursor: cursor, after: after),
                method: "GET",
                token: token
            )
        }
        try requireStatus(200, response: response)
        try StrictSyncJSONValidator.validateBootstrapPage(response.data)
        let page = try decode(BootstrapPageDTO.self, from: response.data)
        return try validatedBootstrapPage(
            page,
            requestedCursor: cursor,
            requestedAfter: after
        )
    }

    public func changes(cursor: Int64) async throws -> BagLogChangePage {
        guard cursor >= 0 else {
            throw BagLogSyncError.invalidRequest
        }
        let response = try await authenticatedResponse(
            maximumResponseSize: Self.maximumPageResponseSize
        ) { token in
            try await self.request(
                path: ["v1", "sync", "changes"],
                queryItems: [
                    URLQueryItem(name: "cursor", value: String(cursor)),
                    URLQueryItem(name: "limit", value: "20")
                ],
                method: "GET",
                token: token
            )
        }
        try requireStatus(200, response: response)
        try StrictSyncJSONValidator.validateChangePage(response.data)
        let page = try decode(ChangePageDTO.self, from: response.data)
        return try validatedChangePage(page, requestedCursor: cursor)
    }
}

// MARK: - Requests

extension BagLogLoadoutAPI {
    private func authenticatedResponse(
        maximumResponseSize: Int,
        request: @Sendable (String) async throws -> URLRequest
    ) async throws -> SecureHTTPResponse {
        let accessToken = try await accessToken()
        let initialRequest = try await request(accessToken)
        var response = try await send(
            initialRequest,
            maximumResponseSize: maximumResponseSize
        )
        guard response.response.statusCode == 401 else {
            return response
        }

        let backendError = decodedBackendError(from: response.data)
        guard backendError?.code == "invalid_token" else {
            throw BagLogSyncError.invalidToken
        }
        let refreshedToken = try await refreshedAccessToken()
        let retryRequest = try await request(refreshedToken)
        response = try await send(
            retryRequest,
            maximumResponseSize: maximumResponseSize
        )
        guard response.response.statusCode != 401 else {
            throw BagLogSyncError.invalidToken
        }
        return response
    }

    private func request(
        path: [String],
        queryItems: [URLQueryItem] = [],
        method: String,
        token: String,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> URLRequest {
        var requestHeaders = headers
        requestHeaders["Accept"] = "application/json"
        requestHeaders["Authorization"] = "Bearer \(token)"
        if body != nil {
            requestHeaders["Content-Type"] = "application/json"
        }
        do {
            return try await client.makeRequest(
                pathComponents: path,
                queryItems: queryItems,
                method: method,
                headers: requestHeaders,
                body: body
            )
        } catch {
            throw BagLogSyncError.configuration
        }
    }

    private func mutationRequest(
        _ attempt: LoadoutMutationAttemptValue,
        token: String
    ) async throws -> URLRequest {
        var headers = [
            "Idempotency-Key": attempt.idempotencyKey.uuidString.lowercased()
        ]
        if let revision = attempt.expectedRevision {
            headers["If-Match"] = Self.etag(revision)
        }
        let path: [String]
        let method: String
        switch attempt.operation {
        case .create:
            path = ["v1", "loadouts"]
            method = "POST"
        case .replace:
            path = ["v1", "loadouts", attempt.loadoutID.uuidString.lowercased()]
            method = "PUT"
        case .delete:
            path = ["v1", "loadouts", attempt.loadoutID.uuidString.lowercased()]
            method = "DELETE"
        }
        return try await request(
            path: path,
            method: method,
            token: token,
            headers: headers,
            body: attempt.encodedBody
        )
    }

    private func send(
        _ request: URLRequest,
        maximumResponseSize: Int
    ) async throws -> SecureHTTPResponse {
        do {
            return try await client.response(
                for: request,
                maximumResponseSize: maximumResponseSize
            )
        } catch let error as SecureHTTPClientError {
            throw mappedClientError(error)
        }
    }

    private func accessToken() async throws -> String {
        do {
            return try await accessTokenProvider.validAccessToken()
        } catch {
            throw BagLogSyncError.invalidToken
        }
    }

    private func refreshedAccessToken() async throws -> String {
        do {
            return try await accessTokenProvider.refreshAccessToken()
        } catch {
            throw BagLogSyncError.invalidToken
        }
    }

    private func bootstrapQuery(
        cursor: Int64?,
        after: UUID?
    ) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: String(cursor)))
        }
        if let after {
            queryItems.append(
                URLQueryItem(name: "after", value: after.uuidString.lowercased())
            )
        }
        queryItems.append(URLQueryItem(name: "limit", value: "20"))
        return queryItems
    }
}

// MARK: - Response decoding

extension BagLogLoadoutAPI {
    private func decodedAggregate(
        from response: SecureHTTPResponse,
        expectedID: UUID
    ) throws -> RemoteLoadoutAggregate {
        try StrictSyncJSONValidator.validateLoadout(response.data)
        let dto = try decode(LoadoutDTO.self, from: response.data)
        let aggregate = try validatedAggregate(dto)
        guard aggregate.projection.id == expectedID else {
            throw BagLogSyncError.unexpectedResponse
        }
        try validateRevisionETag(response.response, revision: aggregate.revision)
        return aggregate
    }

    private func decodedTombstone(
        from response: SecureHTTPResponse,
        expectedID: UUID
    ) throws -> RemoteLoadoutTombstone {
        try StrictSyncJSONValidator.validateTombstone(response.data)
        let dto = try decode(LoadoutTombstoneDTO.self, from: response.data)
        guard dto.id == expectedID, dto.revision > 0 else {
            throw BagLogSyncError.unexpectedResponse
        }
        try validateRevisionETag(response.response, revision: dto.revision)
        return RemoteLoadoutTombstone(
            id: dto.id,
            revision: dto.revision,
            deletedAt: dto.deletedAt
        )
    }

    private func requireStatus(
        _ expectedStatus: Int,
        response: SecureHTTPResponse
    ) throws {
        guard response.response.statusCode == expectedStatus else {
            throw mappedBackendError(response)
        }
    }

    private func mappedBackendError(
        _ response: SecureHTTPResponse
    ) -> BagLogSyncError {
        let error = decodedBackendError(from: response.data)
        let retryAfter = validatedRetryAfter(response.response)
        return switch (response.response.statusCode, error?.code) {
        case (400, "invalid_cursor"):
            .invalidCursor
        case (400, _):
            .invalidRequest
        case (401, _):
            .invalidToken
        case (403, _):
            .forbidden
        case (404, "loadout_not_found"):
            .loadoutNotFound
        case (409, "profile_required"):
            .profileRequired
        case (409, "mutation_in_progress"):
            .mutationInProgress(retryAfter: retryAfter)
        case (409, "idempotency_conflict"):
            .idempotencyConflict(traceID: validatedTraceID(error?.traceID))
        case (409, "loadout_conflict"):
            .loadoutConflict
        case (409, _):
            .profileConflict
        case (410, "cursor_expired"):
            .cursorExpired
        case (412, "revision_mismatch"):
            .revisionMismatch
        case (428, "revision_required"):
            .revisionRequired
        case (500, _):
            .internalError
        case (503, _):
            .serviceUnavailable
        default:
            .unexpectedResponse
        }
    }

    private func decodedBackendError(
        from data: Data
    ) -> BackendErrorDTO? {
        guard data.count <= Self.maximumProfileResponseSize,
              (try? StrictSyncJSONValidator.validateError(data)) != nil,
              let error = try? decoder.decode(BackendErrorDTO.self, from: data),
              error.code.range(
                of: "^[a-z0-9_]+$",
                options: .regularExpression
              ) != nil else {
            return nil
        }
        return error
    }

    private func idempotencyWasReplayed(
        _ response: HTTPURLResponse
    ) throws -> Bool {
        guard let value = response.value(
            forHTTPHeaderField: "Idempotency-Replayed"
        ) else {
            return false
        }
        guard value == "true" else {
            throw BagLogSyncError.unexpectedResponse
        }
        return true
    }

    private func validateRevisionETag(
        _ response: HTTPURLResponse,
        revision: Int64
    ) throws {
        guard revision > 0,
              response.value(forHTTPHeaderField: "ETag") == Self.etag(revision) else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private static func etag(_ revision: Int64) -> String {
        "\"\(revision)\""
    }
}

// MARK: - DTO validation

extension BagLogLoadoutAPI {
    private func validatedAggregate(
        _ dto: LoadoutDTO
    ) throws -> RemoteLoadoutAggregate {
        let projection = LoadoutSyncProjection(
            id: dto.id,
            title: dto.title,
            summary: dto.summary,
            category: dto.category,
            items: dto.items.map(syncItem),
            tags: dto.tags
        )
        try validateProjection(projection)
        guard dto.revision > 0, dto.createdAt <= dto.updatedAt else {
            throw BagLogSyncError.unexpectedResponse
        }
        return RemoteLoadoutAggregate(
            projection: projection,
            revision: dto.revision,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    private func syncItem(_ item: LoadoutItemDTO) -> LoadoutSyncItem {
        LoadoutSyncItem(
            id: item.id,
            title: item.title,
            category: item.category,
            brand: item.brand,
            model: item.model,
            notes: item.notes,
            quantity: item.quantity,
            isEssential: item.isEssential,
            links: item.links.map {
                LoadoutSyncLink(id: $0.id, urlString: $0.url, label: $0.label)
            }
        )
    }

    private func validateProjection(
        _ projection: LoadoutSyncProjection
    ) throws {
        guard isNonblank(projection.title, maximumCount: 160),
              projection.summary.count <= 4_000,
              isNonblank(projection.category, maximumCount: 80),
              projection.items.count <= 100,
              projection.tags.count <= 30,
              Set(projection.items.map(\.id)).count == projection.items.count else {
            throw BagLogSyncError.unexpectedResponse
        }
        try validateTags(projection.tags)
        for item in projection.items {
            try validateItem(item)
        }
    }

    private func validateTags(_ tags: [String]) throws {
        let normalized = tags.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard normalized == tags,
              tags == tags.sorted(),
              Set(tags).count == tags.count,
              tags.allSatisfy({ isNonblank($0, maximumCount: 80) }) else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private func validateItem(_ item: LoadoutSyncItem) throws {
        guard isNonblank(item.title, maximumCount: 240),
              isValidOptional(item.category, maximumCount: 120),
              isValidOptional(item.brand, maximumCount: 160),
              isValidOptional(item.model, maximumCount: 160),
              isValidOptional(item.notes, maximumCount: 4_000),
              (1...10_000).contains(item.quantity),
              item.links.count <= 10,
              Set(item.links.map(\.id)).count == item.links.count else {
            throw BagLogSyncError.unexpectedResponse
        }
        for link in item.links {
            try validateLink(link)
        }
    }

    private func validateLink(_ link: LoadoutSyncLink) throws {
        guard link.urlString.count <= 2_048,
              let url = URL(string: link.urlString),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              isValidOptional(link.label, maximumCount: 160) else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private func validateProfile(_ profile: ProfileDTO) throws {
        do {
            try validateProfileWrite(
                BagLogProfileWrite(
                    handle: profile.handle,
                    displayName: profile.displayName,
                    bio: profile.bio
                )
            )
        } catch {
            throw BagLogSyncError.unexpectedResponse
        }
        guard profile.revision > 0,
              profile.createdAt <= profile.updatedAt else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private func validateProfileWrite(
        _ write: BagLogProfileWrite
    ) throws {
        guard write.handle.range(
            of: "^[A-Za-z0-9_]{3,30}$",
            options: .regularExpression
        ) != nil,
        isNonblank(write.displayName, maximumCount: 80),
        write.bio?.count ?? 0 <= 500 else {
            throw BagLogSyncError.invalidRequest
        }
    }

    private func isNonblank(
        _ value: String,
        maximumCount: Int
    ) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= maximumCount
    }

    private func isValidOptional(
        _ value: String?,
        maximumCount: Int
    ) -> Bool {
        guard let value else {
            return true
        }
        return isNonblank(value, maximumCount: maximumCount)
    }
}

// MARK: - Page validation

extension BagLogLoadoutAPI {
    private func validatedBootstrapPage(
        _ page: BootstrapPageDTO,
        requestedCursor: Int64?,
        requestedAfter: UUID?
    ) throws -> BagLogBootstrapPage {
        guard page.cursor >= 0,
              page.loadouts.count <= 20,
              !page.hasMore || page.nextAfter != nil,
              requestedCursor == nil || requestedCursor == page.cursor,
              requestedAfter == nil || requestedAfter != page.nextAfter else {
            throw BagLogSyncError.unexpectedResponse
        }
        let loadouts = try page.loadouts.map(validatedAggregate)
        try validateBootstrapOrder(loadouts)
        if page.hasMore, page.nextAfter != loadouts.last?.projection.id {
            throw BagLogSyncError.unexpectedResponse
        }
        return BagLogBootstrapPage(
            loadouts: loadouts,
            cursor: page.cursor,
            nextAfter: page.nextAfter,
            hasMore: page.hasMore
        )
    }

    private func validateBootstrapOrder(
        _ loadouts: [RemoteLoadoutAggregate]
    ) throws {
        let identifiers = loadouts.map {
            $0.projection.id.uuidString.lowercased()
        }
        guard identifiers == identifiers.sorted(),
              Set(identifiers).count == identifiers.count else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private func validatedChangePage(
        _ page: ChangePageDTO,
        requestedCursor: Int64
    ) throws -> BagLogChangePage {
        guard page.changes.count <= 20,
              page.nextCursor >= requestedCursor,
              !page.hasMore || !page.changes.isEmpty else {
            throw BagLogSyncError.unexpectedResponse
        }
        var previousCursor = requestedCursor
        var changes: [RemoteLoadoutChange] = []
        for change in page.changes {
            guard change.cursor > previousCursor,
                  change.cursor <= page.nextCursor else {
                throw BagLogSyncError.unexpectedResponse
            }
            changes.append(try validatedChange(change))
            previousCursor = change.cursor
        }
        if let lastCursor = changes.last?.cursor,
           lastCursor != page.nextCursor {
            throw BagLogSyncError.unexpectedResponse
        }
        return BagLogChangePage(
            changes: changes,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore
        )
    }

    private func validatedChange(
        _ change: LoadoutChangeDTO
    ) throws -> RemoteLoadoutChange {
        guard change.cursor >= 0, change.revision > 0 else {
            throw BagLogSyncError.unexpectedResponse
        }
        let payload: RemoteLoadoutChangePayload
        switch (change.operation, change.loadout) {
        case let ("upsert", loadout?):
            let aggregate = try validatedAggregate(loadout)
            guard aggregate.projection.id == change.resourceID,
                  aggregate.revision == change.revision else {
                throw BagLogSyncError.unexpectedResponse
            }
            payload = .upsert(aggregate)
        case ("delete", nil):
            payload = .delete(
                RemoteLoadoutTombstone(
                    id: change.resourceID,
                    revision: change.revision,
                    deletedAt: change.changedAt
                )
            )
        default:
            throw BagLogSyncError.unexpectedResponse
        }
        return RemoteLoadoutChange(
            cursor: change.cursor,
            resourceID: change.resourceID,
            revision: change.revision,
            changedAt: change.changedAt,
            payload: payload
        )
    }
}

// MARK: - Safe utilities

extension BagLogLoadoutAPI {
    private func encode<Value: Encodable>(_ value: Value) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw BagLogSyncError.invalidRequest
        }
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private func mappedClientError(
        _ error: SecureHTTPClientError
    ) -> BagLogSyncError {
        switch error {
        case .cancelled:
            .cancelled
        case .configuration:
            .configuration
        case .networkUnavailable:
            .networkUnavailable
        case .responseTooLarge:
            .responseTooLarge
        case .serviceUnavailable:
            .serviceUnavailable
        case .timedOut:
            .timedOut
        case .unexpectedResponse:
            .unexpectedResponse
        }
    }

    private func validatedRetryAfter(
        _ response: HTTPURLResponse
    ) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Int(value),
              (1...3_600).contains(seconds) else {
            return nil
        }
        return TimeInterval(seconds)
    }

    private func validatedTraceID(_ traceID: String?) -> String? {
        guard let traceID,
              traceID.range(
                of: "^(?:[a-f0-9]{32}|request-id-unavailable)$",
                options: .regularExpression
              ) != nil else {
            return nil
        }
        return traceID
    }

    private static func decodeISO8601Date(
        _ decoder: any Decoder
    ) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let date = try? Date.ISO8601FormatStyle(
            includingFractionalSeconds: true
        ).parse(value) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle(
            includingFractionalSeconds: false
        ).parse(value) {
            return date
        }
        throw BagLogSyncError.unexpectedResponse
    }
}
