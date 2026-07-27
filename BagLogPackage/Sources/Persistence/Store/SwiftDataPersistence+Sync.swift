import Foundation
import SwiftData

extension SwiftDataPersistence {
    // MARK: - Scope

    public func activateSyncScope(
        remoteProfileID: UUID,
        localProfileID: UUID,
        at date: Date
    ) throws -> LoadoutSyncScopeSnapshot {
        _ = try requiredProfile(id: localProfileID)

        let scope: LoadoutSyncScope
        if let existingScope = try fetchSyncScope(remoteProfileID: remoteProfileID) {
            guard existingScope.localProfileID == localProfileID else {
                throw LoadoutSyncPersistenceError.accountScopeMismatch
            }
            existingScope.updatedAt = date
            scope = existingScope
        } else {
            scope = LoadoutSyncScope(
                id: remoteProfileID,
                remoteProfileID: remoteProfileID,
                localProfileID: localProfileID,
                createdAt: date
            )
            modelContext.insert(scope)
        }

        try saveChanges()
        activeSyncScopeID = scope.id
        return syncScopeSnapshot(scope)
    }

    public func deactivateSyncScope() {
        activeSyncScopeID = nil
    }

    public func bindUnboundPrivateDrafts(
        to scopeID: UUID,
        at date: Date
    ) throws {
        let scope = try requiredSyncScope(id: scopeID)
        let ownerID = scope.localProfileID
        let descriptor = FetchDescriptor<Loadout>(
            predicate: #Predicate {
                $0.ownerID == ownerID
                    && $0.visibilityRaw == "private"
                    && $0.statusRaw == "draft"
            }
        )

        do {
            for loadout in try modelContext.fetch(descriptor) {
                try bindEligibleLoadout(loadout, to: scope, at: date)
            }
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    public func syncScope(id: UUID) throws -> LoadoutSyncScopeSnapshot? {
        try fetchSyncScope(id: id).map(syncScopeSnapshot)
    }

    // MARK: - Queue

    public func oldestPendingChange(
        scopeID: UUID
    ) throws -> PendingLoadoutChangeValue? {
        let changes = try pendingChanges(scopeID: scopeID)
        for change in changes where try fetchAttempt(pendingChangeID: change.id) == nil {
            return try pendingChangeValue(change)
        }
        return nil
    }

    public func nextMutationAttempt(
        scopeID: UUID,
        at date: Date
    ) throws -> LoadoutMutationAttemptValue? {
        let changes = try pendingChanges(scopeID: scopeID)
        for change in changes {
            guard let attempt = try fetchAttempt(pendingChangeID: change.id),
                  isAttemptEligible(attempt, at: date) else {
                continue
            }
            return attemptValue(attempt)
        }
        return nil
    }

    public func nextMutationRetryDate(scopeID: UUID) throws -> Date? {
        try mutationAttempts(scopeID: scopeID)
            .filter { $0.state == .retryScheduled }
            .compactMap(\.retryNotBefore)
            .min()
    }

    public func retryFailedMutations(scopeID: UUID) throws {
        for attempt in try mutationAttempts(scopeID: scopeID)
        where attempt.state == .failed {
            attempt.state = .ready
            attempt.failureCode = nil
            attempt.traceID = nil
            attempt.retryNotBefore = nil
        }
        try saveChanges()
    }

    public func materializeAttempt(
        _ command: MaterializeLoadoutAttemptCommand
    ) throws -> LoadoutMutationAttemptValue {
        let pendingChange = try requiredPendingChange(id: command.pendingChangeID)
        guard try fetchAttempt(pendingChangeID: pendingChange.id) == nil else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }

        let metadata = try requiredSyncMetadata(loadoutID: pendingChange.loadoutID)
        let operation = try mutationOperation(
            for: pendingChange,
            revision: metadata.acknowledgedRevision
        )
        try validateBody(command.encodedBody, for: operation)

        let attempt = LoadoutMutationAttempt(
            idempotencyKey: command.idempotencyKey,
            pendingChangeID: pendingChange.id,
            scopeID: pendingChange.scopeID,
            loadoutID: pendingChange.loadoutID,
            operation: operation,
            expectedRevision: metadata.acknowledgedRevision,
            encodedBody: command.encodedBody,
            snapshotData: pendingChange.snapshotData,
            localGeneration: pendingChange.localGeneration
        )
        modelContext.insert(attempt)
        try saveChanges()
        return attemptValue(attempt)
    }

    public func markAttemptStarted(
        idempotencyKey: UUID,
        at date: Date
    ) throws {
        let attempt = try requiredAttempt(idempotencyKey: idempotencyKey)
        if attempt.firstAttemptedAt == nil {
            attempt.firstAttemptedAt = date
        }
        attempt.attemptCount += 1
        attempt.retryNotBefore = nil
        attempt.state = .inFlight
        try saveChanges()
    }

    public func acknowledgeMutation(
        _ acknowledgement: LoadoutMutationAcknowledgement
    ) throws {
        do {
            let attempt = try requiredAttempt(
                idempotencyKey: acknowledgement.idempotencyKey
            )
            let pendingChange = try requiredPendingChange(id: attempt.pendingChangeID)
            try applyAcknowledgement(
                acknowledgement,
                attempt: attempt,
                pendingChange: pendingChange
            )
            modelContext.delete(attempt)
            modelContext.delete(pendingChange)
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    public func scheduleMutationRetry(
        idempotencyKey: UUID,
        notBefore: Date,
        failureCode: String?
    ) throws {
        let attempt = try requiredAttempt(idempotencyKey: idempotencyKey)
        attempt.state = .retryScheduled
        attempt.retryNotBefore = notBefore
        attempt.failureCode = failureCode
        try saveChanges()
    }

    public func failMutation(
        idempotencyKey: UUID,
        failureCode: String,
        traceID: String?
    ) throws {
        let attempt = try requiredAttempt(idempotencyKey: idempotencyKey)
        attempt.state = .failed
        attempt.failureCode = failureCode
        attempt.traceID = traceID
        try updateScopeFailure(scopeID: attempt.scopeID, code: failureCode)
        try saveChanges()
    }

    // MARK: - Conflicts

    public func recordMutationConflict(
        idempotencyKey: UUID,
        remoteVersion: LoadoutConflictRemoteVersion,
        detectedAt: Date
    ) throws {
        do {
            let attempt = try requiredAttempt(idempotencyKey: idempotencyKey)
            let localSnapshot = try decodeSnapshot(attempt.snapshotData)
            try storeConflict(
                scopeID: attempt.scopeID,
                loadoutID: attempt.loadoutID,
                baseRevision: attempt.expectedRevision,
                localOperation: attempt.operation,
                localSnapshot: localSnapshot,
                remoteVersion: remoteVersion,
                detectedAt: detectedAt
            )
            attempt.state = .conflicted
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    public func conflict(
        loadoutID: UUID
    ) throws -> LoadoutConflictSnapshot? {
        try fetchConflict(loadoutID: loadoutID).map(conflictSnapshot)
    }

    public func resolveConflict(
        loadoutID: UUID,
        resolution: LoadoutConflictResolution,
        at date: Date
    ) throws -> LoadoutSnapshot? {
        do {
            let conflict = try requiredConflict(loadoutID: loadoutID)
            let result = try performResolution(
                resolution,
                conflict: conflict,
                at: date
            )
            let snapshot = try result.map(loadoutSnapshot)
            try saveChanges()
            return snapshot
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    // MARK: - Pull

    public func applyBootstrapPage(
        scopeID: UUID,
        loadouts: [RemoteLoadoutAggregate],
        cursor: Int64,
        nextAfter: UUID?,
        hasMore: Bool,
        appliedAt: Date
    ) throws {
        do {
            let scope = try requiredSyncScope(id: scopeID)
            try validateBootstrapPage(
                scope: scope,
                cursor: cursor,
                nextAfter: nextAfter,
                hasMore: hasMore
            )
            for loadout in loadouts {
                try applyRemoteAggregate(loadout, to: scope, at: appliedAt)
            }
            updateBootstrapProgress(
                scope,
                cursor: cursor,
                nextAfter: nextAfter,
                hasMore: hasMore,
                appliedAt: appliedAt
            )
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    public func applyChangePage(
        scopeID: UUID,
        changes: [RemoteLoadoutChange],
        nextCursor: Int64,
        hasMore: Bool,
        appliedAt: Date
    ) throws {
        do {
            let scope = try requiredSyncScope(id: scopeID)
            try validateChangePage(
                changes,
                currentCursor: scope.cursor,
                nextCursor: nextCursor,
                hasMore: hasMore
            )
            for change in changes {
                try applyRemoteChange(change, to: scope, at: appliedAt)
            }
            scope.cursor = nextCursor
            scope.lastCompletedAt = hasMore ? scope.lastCompletedAt : appliedAt
            scope.lastFailureCode = nil
            scope.updatedAt = appliedAt
            try saveChanges()
        } catch {
            modelContext.rollback()
            throw mappedSyncPersistenceError(error)
        }
    }

    public func resetPullState(scopeID: UUID, at date: Date) throws {
        let scope = try requiredSyncScope(id: scopeID)
        scope.cursor = nil
        scope.bootstrapCursor = nil
        scope.bootstrapAfter = nil
        scope.bootstrapState = .notStarted
        scope.lastFailureCode = nil
        scope.updatedAt = date
        try saveChanges()
    }
}

// MARK: - Local transactions

extension SwiftDataPersistence {
    func recordLocalSyncChange(
        for loadout: Loadout,
        wasEligible: Bool,
        at date: Date
    ) throws {
        if isEligibleForPrivateSync(loadout) {
            try enqueueEligibleUpsert(loadout, at: date)
            return
        }
        let hasSyncMetadata = try fetchSyncMetadata(loadoutID: loadout.id) != nil
        if wasEligible || hasSyncMetadata {
            try enqueueEligibilityDetach(loadout, at: date)
        }
    }

    func recordLocalDeletion(of loadout: Loadout, at date: Date) throws {
        guard let metadata = try fetchSyncMetadata(loadoutID: loadout.id) else {
            return
        }
        if metadata.isDetached || metadata.scopeID == nil {
            try clearSyncWork(loadoutID: loadout.id)
            modelContext.delete(metadata)
            return
        }

        let snapshot = try loadoutSnapshot(loadout)
        if try cancelNeverSentCreate(loadoutID: loadout.id, metadata: metadata) {
            return
        }
        try enqueueChange(
            kind: .delete,
            deleteReason: .userDeleted,
            snapshot: snapshot,
            metadata: metadata,
            at: date
        )
    }

    func isEligibleForPrivateSync(_ loadout: Loadout) -> Bool {
        loadout.visibility == .private && loadout.status == .draft
    }

    private func enqueueEligibleUpsert(
        _ loadout: Loadout,
        at date: Date
    ) throws {
        if let conflict = try fetchConflict(loadoutID: loadout.id) {
            conflict.localSnapshotData = try encodeSnapshot(loadoutSnapshot(loadout))
            return
        }
        let metadata = try metadataForEligibleChange(loadout, at: date)
        guard let metadata else {
            return
        }
        guard !metadata.isDetached else {
            throw LoadoutSyncPersistenceError.detachedLoadoutCannotResynchronize
        }
        try enqueueChange(
            kind: .upsert,
            deleteReason: nil,
            snapshot: loadoutSnapshot(loadout),
            metadata: metadata,
            at: date
        )
    }

    private func enqueueEligibilityDetach(
        _ loadout: Loadout,
        at date: Date
    ) throws {
        guard let metadata = try fetchSyncMetadata(loadoutID: loadout.id),
              !metadata.isDetached,
              metadata.scopeID != nil else {
            return
        }
        if try cancelNeverSentCreate(loadoutID: loadout.id, metadata: metadata) {
            return
        }
        try enqueueChange(
            kind: .delete,
            deleteReason: .eligibilityDetach,
            snapshot: loadoutSnapshot(loadout),
            metadata: metadata,
            at: date
        )
    }

    private func metadataForEligibleChange(
        _ loadout: Loadout,
        at date: Date
    ) throws -> LoadoutSyncMetadata? {
        if let metadata = try fetchSyncMetadata(loadoutID: loadout.id) {
            if metadata.scopeID == nil {
                try bind(metadata, toActiveScopeFor: loadout.ownerID)
            }
            return metadata.scopeID == nil ? nil : metadata
        }
        guard let scope = try activeScope(for: loadout.ownerID) else {
            return nil
        }
        let metadata = LoadoutSyncMetadata(
            loadoutID: loadout.id,
            scopeID: scope.id,
            updatedAt: date
        )
        modelContext.insert(metadata)
        return metadata
    }

    private func bind(
        _ metadata: LoadoutSyncMetadata,
        toActiveScopeFor ownerID: UUID
    ) throws {
        guard let scope = try activeScope(for: ownerID) else {
            return
        }
        metadata.scopeID = scope.id
    }

    private func activeScope(for ownerID: UUID) throws -> LoadoutSyncScope? {
        guard let activeSyncScopeID,
              let scope = try fetchSyncScope(id: activeSyncScopeID),
              scope.localProfileID == ownerID else {
            return nil
        }
        return scope
    }

    private func enqueueChange(
        kind: PendingLoadoutChangeKind,
        deleteReason: LoadoutDeleteReason?,
        snapshot: LoadoutSnapshot,
        metadata: LoadoutSyncMetadata,
        at date: Date
    ) throws {
        guard let scopeID = metadata.scopeID else {
            throw LoadoutSyncPersistenceError.scopeNotFound
        }
        metadata.localGeneration = try nextGeneration(after: metadata.localGeneration)
        metadata.updatedAt = date
        let snapshotData = try encodeSnapshot(snapshot)

        if let coalescible = try coalescibleChange(
            scopeID: scopeID,
            loadoutID: snapshot.id
        ) {
            coalescible.kind = kind
            coalescible.deleteReason = deleteReason
            coalescible.localGeneration = metadata.localGeneration
            coalescible.snapshotData = snapshotData
            return
        }
        modelContext.insert(
            PendingLoadoutChange(
                scopeID: scopeID,
                loadoutID: snapshot.id,
                kind: kind,
                deleteReason: deleteReason,
                localGeneration: metadata.localGeneration,
                snapshotData: snapshotData,
                createdAt: date
            )
        )
    }

    private func cancelNeverSentCreate(
        loadoutID: UUID,
        metadata: LoadoutSyncMetadata
    ) throws -> Bool {
        guard metadata.acknowledgedRevision == nil else {
            return false
        }
        let attempts = try attempts(loadoutID: loadoutID)
        guard attempts.allSatisfy({
            $0.operation == .create && $0.firstAttemptedAt == nil
        }) else {
            return false
        }
        try clearSyncWork(loadoutID: loadoutID)
        modelContext.delete(metadata)
        return true
    }

    private func bindEligibleLoadout(
        _ loadout: Loadout,
        to scope: LoadoutSyncScope,
        at date: Date
    ) throws {
        let metadata: LoadoutSyncMetadata
        if let existingMetadata = try fetchSyncMetadata(loadoutID: loadout.id) {
            guard existingMetadata.scopeID == nil || existingMetadata.scopeID == scope.id else {
                return
            }
            guard !existingMetadata.isDetached else {
                return
            }
            existingMetadata.scopeID = scope.id
            metadata = existingMetadata
        } else {
            metadata = LoadoutSyncMetadata(
                loadoutID: loadout.id,
                scopeID: scope.id,
                updatedAt: date
            )
            modelContext.insert(metadata)
        }

        guard try pendingChanges(
            scopeID: scope.id,
            loadoutID: loadout.id
        ).isEmpty else {
            return
        }
        try enqueueChange(
            kind: .upsert,
            deleteReason: nil,
            snapshot: loadoutSnapshot(loadout),
            metadata: metadata,
            at: date
        )
    }
}

// MARK: - Acknowledgements

extension SwiftDataPersistence {
    private func applyAcknowledgement(
        _ acknowledgement: LoadoutMutationAcknowledgement,
        attempt: LoadoutMutationAttempt,
        pendingChange: PendingLoadoutChange
    ) throws {
        switch acknowledgement.result {
        case let .aggregate(aggregate):
            try acknowledgeAggregate(
                aggregate,
                attempt: attempt,
                acknowledgedAt: acknowledgement.acknowledgedAt
            )
        case let .tombstone(tombstone):
            try acknowledgeTombstone(
                tombstone,
                attempt: attempt,
                pendingChange: pendingChange,
                acknowledgedAt: acknowledgement.acknowledgedAt
            )
        }
    }

    private func acknowledgeAggregate(
        _ aggregate: RemoteLoadoutAggregate,
        attempt: LoadoutMutationAttempt,
        acknowledgedAt: Date
    ) throws {
        guard attempt.operation != .delete,
              aggregate.projection.id == attempt.loadoutID,
              aggregate.revision > 0 else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        let metadata = try requiredSyncMetadata(loadoutID: attempt.loadoutID)
        metadata.acknowledgedRevision = aggregate.revision
        metadata.remoteCreatedAt = aggregate.createdAt
        metadata.remoteUpdatedAt = aggregate.updatedAt
        metadata.lastSyncedAt = acknowledgedAt
        metadata.updatedAt = acknowledgedAt
        try markScopeCompleted(scopeID: attempt.scopeID, at: acknowledgedAt)
    }

    private func acknowledgeTombstone(
        _ tombstone: RemoteLoadoutTombstone,
        attempt: LoadoutMutationAttempt,
        pendingChange: PendingLoadoutChange,
        acknowledgedAt: Date
    ) throws {
        guard attempt.operation == .delete,
              tombstone.id == attempt.loadoutID,
              tombstone.revision > 0 else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        let metadata = try requiredSyncMetadata(loadoutID: attempt.loadoutID)
        metadata.acknowledgedRevision = tombstone.revision
        metadata.remoteUpdatedAt = tombstone.deletedAt
        metadata.lastSyncedAt = acknowledgedAt
        metadata.updatedAt = acknowledgedAt

        if pendingChange.deleteReason == .eligibilityDetach {
            metadata.isDetached = true
        } else {
            modelContext.delete(metadata)
        }
        try markScopeCompleted(scopeID: attempt.scopeID, at: acknowledgedAt)
    }
}

// MARK: - Remote application

extension SwiftDataPersistence {
    private func applyRemoteChange(
        _ change: RemoteLoadoutChange,
        to scope: LoadoutSyncScope,
        at date: Date
    ) throws {
        switch change.payload {
        case let .upsert(aggregate):
            try applyRemoteAggregate(aggregate, to: scope, at: date)
        case let .delete(tombstone):
            try applyRemoteTombstone(tombstone, to: scope, at: date)
        }
    }

    private func applyRemoteAggregate(
        _ aggregate: RemoteLoadoutAggregate,
        to scope: LoadoutSyncScope,
        at date: Date
    ) throws {
        let loadoutID = aggregate.projection.id
        let metadata = try syncMetadata(
            loadoutID: loadoutID,
            scopeID: scope.id,
            at: date
        )
        guard aggregate.revision > (metadata.acknowledgedRevision ?? 0) else {
            return
        }
        guard !metadata.isDetached else {
            return
        }

        let pending = try pendingChanges(scopeID: scope.id, loadoutID: loadoutID)
        if !pending.isEmpty {
            if try isSafeRemoteEcho(aggregate, pendingChanges: pending) {
                acknowledgeRemoteEcho(aggregate, metadata: metadata, at: date)
            } else if pending.allSatisfy({ $0.kind == .delete }) {
                acknowledgeRemoteEcho(aggregate, metadata: metadata, at: date)
            } else {
                try conflictWithRemoteAggregate(
                    aggregate,
                    scope: scope,
                    metadata: metadata,
                    detectedAt: date
                )
            }
            return
        }

        if let localLoadout = try fetchLoadout(id: loadoutID),
           !isEligibleForPrivateSync(localLoadout) {
            return
        }
        try replaceSynchronizedProjection(
            with: aggregate,
            scope: scope,
            metadata: metadata,
            at: date
        )
    }

    private func applyRemoteTombstone(
        _ tombstone: RemoteLoadoutTombstone,
        to scope: LoadoutSyncScope,
        at date: Date
    ) throws {
        guard let metadata = try fetchSyncMetadata(loadoutID: tombstone.id),
              metadata.scopeID == scope.id,
              tombstone.revision > (metadata.acknowledgedRevision ?? 0) else {
            return
        }

        let pending = try pendingChanges(scopeID: scope.id, loadoutID: tombstone.id)
        if !pending.isEmpty {
            if pending.allSatisfy({ $0.kind == .delete }) {
                try reconcilePendingDelete(
                    pending,
                    with: tombstone,
                    metadata: metadata,
                    at: date
                )
            } else {
                try conflictWithRemoteTombstone(
                    tombstone,
                    scope: scope,
                    metadata: metadata,
                    detectedAt: date
                )
            }
            return
        }

        if metadata.isDetached {
            metadata.acknowledgedRevision = tombstone.revision
            metadata.remoteUpdatedAt = tombstone.deletedAt
            metadata.lastSyncedAt = date
            return
        }
        if let loadout = try fetchLoadout(id: tombstone.id) {
            modelContext.delete(loadout)
        }
        modelContext.delete(metadata)
    }

    private func reconcilePendingDelete(
        _ pendingChanges: [PendingLoadoutChange],
        with tombstone: RemoteLoadoutTombstone,
        metadata: LoadoutSyncMetadata,
        at date: Date
    ) throws {
        let deleteReason = pendingChanges.last?.deleteReason
        try clearSyncWork(loadoutID: tombstone.id)
        if deleteReason == .eligibilityDetach {
            metadata.acknowledgedRevision = tombstone.revision
            metadata.remoteUpdatedAt = tombstone.deletedAt
            metadata.lastSyncedAt = date
            metadata.isDetached = true
            metadata.updatedAt = date
        } else {
            if let loadout = try fetchLoadout(id: tombstone.id) {
                modelContext.delete(loadout)
            }
            modelContext.delete(metadata)
        }
    }

    private func replaceSynchronizedProjection(
        with aggregate: RemoteLoadoutAggregate,
        scope: LoadoutSyncScope,
        metadata: LoadoutSyncMetadata,
        at date: Date
    ) throws {
        let loadout = try synchronizedLoadout(
            for: aggregate,
            ownerID: scope.localProfileID
        )
        loadout.title = aggregate.projection.title
        loadout.summary = aggregate.projection.summary
        loadout.category = LoadoutCategory(rawValue: aggregate.projection.category)
        loadout.updatedAt = aggregate.updatedAt
        try replaceTags(
            on: loadout,
            with: aggregate.projection.tags,
            now: aggregate.updatedAt
        )
        try replaceItems(
            on: loadout,
            with: aggregate.projection.items.map(itemCommand)
        )
        acknowledgeRemoteEcho(aggregate, metadata: metadata, at: date)
    }

    private func synchronizedLoadout(
        for aggregate: RemoteLoadoutAggregate,
        ownerID: UUID
    ) throws -> Loadout {
        if let existingLoadout = try fetchLoadout(id: aggregate.projection.id) {
            return existingLoadout
        }
        let owner = try requiredProfile(id: ownerID)
        let loadout = Loadout(
            id: aggregate.projection.id,
            ownerID: ownerID,
            title: aggregate.projection.title,
            summary: aggregate.projection.summary,
            category: LoadoutCategory(rawValue: aggregate.projection.category),
            visibility: .private,
            status: .draft,
            syncState: .synced,
            createdAt: aggregate.createdAt,
            updatedAt: aggregate.updatedAt
        )
        loadout.owner = owner
        modelContext.insert(loadout)
        return loadout
    }

    private func itemCommand(_ item: LoadoutSyncItem) -> LoadoutItemCommand {
        LoadoutItemCommand(
            id: item.id,
            title: item.title,
            category: item.category,
            brand: item.brand,
            model: item.model,
            notes: item.notes,
            quantity: item.quantity,
            isEssential: item.isEssential,
            links: item.links.map {
                ItemLinkCommand(
                    id: $0.id,
                    urlString: $0.urlString,
                    label: $0.label
                )
            }
        )
    }

    private func acknowledgeRemoteEcho(
        _ aggregate: RemoteLoadoutAggregate,
        metadata: LoadoutSyncMetadata,
        at date: Date
    ) {
        metadata.acknowledgedRevision = aggregate.revision
        metadata.remoteCreatedAt = aggregate.createdAt
        metadata.remoteUpdatedAt = aggregate.updatedAt
        metadata.lastSyncedAt = date
        metadata.updatedAt = date
    }
}

// MARK: - Conflict resolution

extension SwiftDataPersistence {
    private func performResolution(
        _ resolution: LoadoutConflictResolution,
        conflict: LoadoutConflict,
        at date: Date
    ) throws -> Loadout? {
        switch resolution {
        case .useThisDevice:
            return try keepLocalVersion(conflict: conflict, at: date)
        case .useServerVersion:
            return try keepRemoteVersion(conflict: conflict, at: date)
        case .saveAsNewDraft:
            return try cloneAfterRemoteDeletion(conflict: conflict, at: date)
        case .acceptDeletion:
            try acceptRemoteDeletion(conflict: conflict)
            return nil
        }
    }

    private func keepLocalVersion(
        conflict: LoadoutConflict,
        at date: Date
    ) throws -> Loadout? {
        let localIntent = try conflictLocalIntent(loadoutID: conflict.loadoutID)
        if localIntent.operation == .delete {
            return try keepLocalDelete(
                conflict: conflict,
                deleteReason: localIntent.deleteReason,
                at: date
            )
        }
        guard !conflict.isRemoteTombstone else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        let localSnapshot = try decodeSnapshot(conflict.localSnapshotData)
        let loadout = try restoreSnapshot(localSnapshot)
        try clearSyncWork(loadoutID: conflict.loadoutID)
        let metadata = try syncMetadata(
            loadoutID: conflict.loadoutID,
            scopeID: conflict.scopeID,
            at: date
        )
        metadata.acknowledgedRevision = conflict.remoteRevision
        metadata.isDetached = false
        try enqueueChange(
            kind: .upsert,
            deleteReason: nil,
            snapshot: localSnapshot,
            metadata: metadata,
            at: date
        )
        modelContext.delete(conflict)
        return loadout
    }

    private func keepLocalDelete(
        conflict: LoadoutConflict,
        deleteReason: LoadoutDeleteReason?,
        at date: Date
    ) throws -> Loadout? {
        let deleteReason = deleteReason ?? .userDeleted
        try clearSyncWork(loadoutID: conflict.loadoutID)
        let metadata = try syncMetadata(
            loadoutID: conflict.loadoutID,
            scopeID: conflict.scopeID,
            at: date
        )
        metadata.acknowledgedRevision = conflict.remoteRevision
        metadata.remoteCreatedAt = conflict.remoteCreatedAt
        metadata.remoteUpdatedAt = conflict.remoteChangedAt

        if conflict.isRemoteTombstone {
            if deleteReason == .eligibilityDetach {
                metadata.isDetached = true
                metadata.lastSyncedAt = date
                modelContext.delete(conflict)
                return try fetchLoadout(id: conflict.loadoutID)
            }
            if let loadout = try fetchLoadout(id: conflict.loadoutID) {
                modelContext.delete(loadout)
            }
            modelContext.delete(metadata)
            modelContext.delete(conflict)
            return nil
        }

        if deleteReason == .userDeleted,
           let loadout = try fetchLoadout(id: conflict.loadoutID) {
            modelContext.delete(loadout)
        }
        try enqueueChange(
            kind: .delete,
            deleteReason: deleteReason,
            snapshot: try decodeSnapshot(conflict.localSnapshotData),
            metadata: metadata,
            at: date
        )
        modelContext.delete(conflict)
        if deleteReason == .eligibilityDetach {
            return try fetchLoadout(id: conflict.loadoutID)
        }
        return nil
    }

    private func keepRemoteVersion(
        conflict: LoadoutConflict,
        at date: Date
    ) throws -> Loadout {
        guard !conflict.isRemoteTombstone,
              let remoteSnapshotData = conflict.remoteSnapshotData else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        let projection = try decodeProjection(remoteSnapshotData)
        let aggregate = RemoteLoadoutAggregate(
            projection: projection,
            revision: conflict.remoteRevision,
            createdAt: conflict.remoteCreatedAt ?? conflict.remoteChangedAt,
            updatedAt: conflict.remoteChangedAt
        )
        let scope = try requiredSyncScope(id: conflict.scopeID)
        try clearSyncWork(loadoutID: conflict.loadoutID)
        let metadata = try syncMetadata(
            loadoutID: conflict.loadoutID,
            scopeID: conflict.scopeID,
            at: date
        )
        try replaceSynchronizedProjection(
            with: aggregate,
            scope: scope,
            metadata: metadata,
            at: date
        )
        modelContext.delete(conflict)
        return try requiredLoadout(id: conflict.loadoutID)
    }

    private func cloneAfterRemoteDeletion(
        conflict: LoadoutConflict,
        at date: Date
    ) throws -> Loadout {
        guard conflict.isRemoteTombstone else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        let localSnapshot = try decodeSnapshot(conflict.localSnapshotData)
        try clearSyncWork(loadoutID: conflict.loadoutID)
        if let oldLoadout = try fetchLoadout(id: conflict.loadoutID) {
            modelContext.delete(oldLoadout)
        }
        if let metadata = try fetchSyncMetadata(loadoutID: conflict.loadoutID) {
            modelContext.delete(metadata)
        }

        let clone = try cloneSnapshotAsDraft(localSnapshot, at: date)
        let metadata = LoadoutSyncMetadata(
            loadoutID: clone.id,
            scopeID: conflict.scopeID,
            updatedAt: date
        )
        modelContext.insert(metadata)
        try enqueueChange(
            kind: .upsert,
            deleteReason: nil,
            snapshot: loadoutSnapshot(clone),
            metadata: metadata,
            at: date
        )
        modelContext.delete(conflict)
        return clone
    }

    private func acceptRemoteDeletion(conflict: LoadoutConflict) throws {
        guard conflict.isRemoteTombstone else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        try clearSyncWork(loadoutID: conflict.loadoutID)
        if let loadout = try fetchLoadout(id: conflict.loadoutID) {
            modelContext.delete(loadout)
        }
        if let metadata = try fetchSyncMetadata(loadoutID: conflict.loadoutID) {
            modelContext.delete(metadata)
        }
        modelContext.delete(conflict)
    }
}

// MARK: - Conflict construction

extension SwiftDataPersistence {
    private func conflictWithRemoteAggregate(
        _ aggregate: RemoteLoadoutAggregate,
        scope: LoadoutSyncScope,
        metadata: LoadoutSyncMetadata,
        detectedAt: Date
    ) throws {
        let localSnapshot = try recoverySnapshot(loadoutID: aggregate.projection.id)
        try storeConflict(
            scopeID: scope.id,
            loadoutID: aggregate.projection.id,
            baseRevision: metadata.acknowledgedRevision,
            localOperation: metadata.acknowledgedRevision == nil ? .create : .replace,
            localSnapshot: localSnapshot,
            remoteVersion: .aggregate(aggregate),
            detectedAt: detectedAt
        )
    }

    private func conflictWithRemoteTombstone(
        _ tombstone: RemoteLoadoutTombstone,
        scope: LoadoutSyncScope,
        metadata: LoadoutSyncMetadata,
        detectedAt: Date
    ) throws {
        let localSnapshot = try recoverySnapshot(loadoutID: tombstone.id)
        try storeConflict(
            scopeID: scope.id,
            loadoutID: tombstone.id,
            baseRevision: metadata.acknowledgedRevision,
            localOperation: metadata.acknowledgedRevision == nil ? .create : .replace,
            localSnapshot: localSnapshot,
            remoteVersion: .tombstone(tombstone),
            detectedAt: detectedAt
        )
    }

    private func storeConflict(
        scopeID: UUID,
        loadoutID: UUID,
        baseRevision: Int64?,
        localOperation: LoadoutMutationOperation,
        localSnapshot: LoadoutSnapshot,
        remoteVersion: LoadoutConflictRemoteVersion,
        detectedAt: Date
    ) throws {
        let values = try conflictRemoteValues(remoteVersion)
        if localOperation == .delete,
           try fetchLoadout(id: loadoutID) == nil {
            _ = try restoreSnapshot(localSnapshot)
        }
        if let conflict = try fetchConflict(loadoutID: loadoutID) {
            conflict.baseRevision = baseRevision
            conflict.localSnapshotData = try encodeSnapshot(localSnapshot)
            conflict.remoteSnapshotData = values.snapshotData
            conflict.remoteRevision = values.revision
            conflict.remoteCreatedAt = values.createdAt
            conflict.remoteChangedAt = values.changedAt
            conflict.isRemoteTombstone = values.isTombstone
            conflict.detectedAt = detectedAt
            return
        }
        modelContext.insert(
            LoadoutConflict(
                scopeID: scopeID,
                loadoutID: loadoutID,
                baseRevision: baseRevision,
                localSnapshotData: try encodeSnapshot(localSnapshot),
                remoteSnapshotData: values.snapshotData,
                remoteRevision: values.revision,
                remoteCreatedAt: values.createdAt,
                remoteChangedAt: values.changedAt,
                isRemoteTombstone: values.isTombstone,
                detectedAt: detectedAt
            )
        )
    }

    private func conflictRemoteValues(
        _ version: LoadoutConflictRemoteVersion
    ) throws -> (
        snapshotData: Data?,
        revision: Int64,
        createdAt: Date?,
        changedAt: Date,
        isTombstone: Bool
    ) {
        switch version {
        case let .aggregate(aggregate):
            return (
                try encodeProjection(aggregate.projection),
                aggregate.revision,
                aggregate.createdAt,
                aggregate.updatedAt,
                false
            )
        case let .tombstone(tombstone):
            return (
                nil,
                tombstone.revision,
                nil,
                tombstone.deletedAt,
                true
            )
        }
    }
}

// MARK: - Fetching and mapping

extension SwiftDataPersistence {
    func fetchSyncMetadata(loadoutID: UUID) throws -> LoadoutSyncMetadata? {
        let descriptor = FetchDescriptor<LoadoutSyncMetadata>(
            predicate: #Predicate { $0.loadoutID == loadoutID }
        )
        return try fetchFirst(descriptor)
    }

    func derivedSyncState(
        loadoutID: UUID,
        metadata: LoadoutSyncMetadata?
    ) throws -> LoadoutSyncState {
        if try fetchConflict(loadoutID: loadoutID) != nil {
            return .conflicted
        }
        let attempts = try attempts(loadoutID: loadoutID)
        if attempts.contains(where: { $0.state == .failed }) {
            return .failed
        }
        let pendingChanges = try pendingChanges(loadoutID: loadoutID)
        if !attempts.isEmpty || !pendingChanges.isEmpty {
            return .waiting
        }
        if metadata?.acknowledgedRevision != nil, metadata?.isDetached == false {
            return .synced
        }
        return .local
    }

    private func fetchSyncScope(id: UUID) throws -> LoadoutSyncScope? {
        let descriptor = FetchDescriptor<LoadoutSyncScope>(
            predicate: #Predicate { $0.id == id }
        )
        return try fetchFirst(descriptor)
    }

    private func fetchSyncScope(
        remoteProfileID: UUID
    ) throws -> LoadoutSyncScope? {
        let descriptor = FetchDescriptor<LoadoutSyncScope>(
            predicate: #Predicate { $0.remoteProfileID == remoteProfileID }
        )
        return try fetchFirst(descriptor)
    }

    private func requiredSyncScope(id: UUID) throws -> LoadoutSyncScope {
        guard let scope = try fetchSyncScope(id: id) else {
            throw LoadoutSyncPersistenceError.scopeNotFound
        }
        return scope
    }

    private func requiredSyncMetadata(
        loadoutID: UUID
    ) throws -> LoadoutSyncMetadata {
        guard let metadata = try fetchSyncMetadata(loadoutID: loadoutID) else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        return metadata
    }

    private func pendingChanges(
        scopeID: UUID
    ) throws -> [PendingLoadoutChange] {
        let descriptor = FetchDescriptor<PendingLoadoutChange>(
            predicate: #Predicate { $0.scopeID == scopeID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try fetch(descriptor)
    }

    private func pendingChanges(
        scopeID: UUID,
        loadoutID: UUID
    ) throws -> [PendingLoadoutChange] {
        let descriptor = FetchDescriptor<PendingLoadoutChange>(
            predicate: #Predicate {
                $0.scopeID == scopeID && $0.loadoutID == loadoutID
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try fetch(descriptor)
    }

    private func pendingChanges(
        loadoutID: UUID
    ) throws -> [PendingLoadoutChange] {
        let descriptor = FetchDescriptor<PendingLoadoutChange>(
            predicate: #Predicate { $0.loadoutID == loadoutID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try fetch(descriptor)
    }

    private func requiredPendingChange(
        id: UUID
    ) throws -> PendingLoadoutChange {
        let descriptor = FetchDescriptor<PendingLoadoutChange>(
            predicate: #Predicate { $0.id == id }
        )
        guard let pendingChange = try fetchFirst(descriptor) else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        return pendingChange
    }

    private func coalescibleChange(
        scopeID: UUID,
        loadoutID: UUID
    ) throws -> PendingLoadoutChange? {
        let changes = try pendingChanges(scopeID: scopeID, loadoutID: loadoutID)
        for change in changes.reversed()
        where try fetchAttempt(pendingChangeID: change.id) == nil {
            return change
        }
        return nil
    }

    private func fetchAttempt(
        pendingChangeID: UUID
    ) throws -> LoadoutMutationAttempt? {
        let descriptor = FetchDescriptor<LoadoutMutationAttempt>(
            predicate: #Predicate { $0.pendingChangeID == pendingChangeID }
        )
        return try fetchFirst(descriptor)
    }

    private func fetchAttempt(
        idempotencyKey: UUID
    ) throws -> LoadoutMutationAttempt? {
        let descriptor = FetchDescriptor<LoadoutMutationAttempt>(
            predicate: #Predicate { $0.idempotencyKey == idempotencyKey }
        )
        return try fetchFirst(descriptor)
    }

    private func requiredAttempt(
        idempotencyKey: UUID
    ) throws -> LoadoutMutationAttempt {
        guard let attempt = try fetchAttempt(idempotencyKey: idempotencyKey) else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        return attempt
    }

    private func attempts(
        loadoutID: UUID
    ) throws -> [LoadoutMutationAttempt] {
        let descriptor = FetchDescriptor<LoadoutMutationAttempt>(
            predicate: #Predicate { $0.loadoutID == loadoutID }
        )
        return try fetch(descriptor)
    }

    private func mutationAttempts(
        scopeID: UUID
    ) throws -> [LoadoutMutationAttempt] {
        let descriptor = FetchDescriptor<LoadoutMutationAttempt>(
            predicate: #Predicate { $0.scopeID == scopeID }
        )
        return try fetch(descriptor)
    }

    private func fetchConflict(
        loadoutID: UUID
    ) throws -> LoadoutConflict? {
        let descriptor = FetchDescriptor<LoadoutConflict>(
            predicate: #Predicate { $0.loadoutID == loadoutID }
        )
        return try fetchFirst(descriptor)
    }

    private func requiredConflict(
        loadoutID: UUID
    ) throws -> LoadoutConflict {
        guard let conflict = try fetchConflict(loadoutID: loadoutID) else {
            throw LoadoutSyncPersistenceError.conflictNotFound
        }
        return conflict
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PersistenceError.queryFailed
        }
    }

    private func fetchFirst<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> T? {
        try fetch(descriptor).first
    }
}

// MARK: - Value mapping

extension SwiftDataPersistence {
    private func syncScopeSnapshot(
        _ scope: LoadoutSyncScope
    ) -> LoadoutSyncScopeSnapshot {
        LoadoutSyncScopeSnapshot(
            id: scope.id,
            remoteProfileID: scope.remoteProfileID,
            localProfileID: scope.localProfileID,
            cursor: scope.cursor,
            bootstrapCursor: scope.bootstrapCursor,
            bootstrapAfter: scope.bootstrapAfter,
            bootstrapState: scope.bootstrapState,
            lastCompletedAt: scope.lastCompletedAt,
            lastFailureCode: scope.lastFailureCode
        )
    }

    private func pendingChangeValue(
        _ change: PendingLoadoutChange
    ) throws -> PendingLoadoutChangeValue {
        let metadata = try requiredSyncMetadata(loadoutID: change.loadoutID)
        return PendingLoadoutChangeValue(
            id: change.id,
            scopeID: change.scopeID,
            loadoutID: change.loadoutID,
            kind: change.kind,
            deleteReason: change.deleteReason,
            localGeneration: change.localGeneration,
            snapshot: try decodeSnapshot(change.snapshotData),
            expectedRevision: metadata.acknowledgedRevision,
            createdAt: change.createdAt
        )
    }

    private func attemptValue(
        _ attempt: LoadoutMutationAttempt
    ) -> LoadoutMutationAttemptValue {
        LoadoutMutationAttemptValue(
            idempotencyKey: attempt.idempotencyKey,
            pendingChangeID: attempt.pendingChangeID,
            scopeID: attempt.scopeID,
            loadoutID: attempt.loadoutID,
            operation: attempt.operation,
            expectedRevision: attempt.expectedRevision,
            encodedBody: attempt.encodedBody,
            localGeneration: attempt.localGeneration,
            state: attempt.state,
            firstAttemptedAt: attempt.firstAttemptedAt,
            retryNotBefore: attempt.retryNotBefore,
            attemptCount: attempt.attemptCount
        )
    }

    private func conflictSnapshot(
        _ conflict: LoadoutConflict
    ) throws -> LoadoutConflictSnapshot {
        let localIntent = try conflictLocalIntent(loadoutID: conflict.loadoutID)
        let remoteVersion: LoadoutConflictRemoteVersion
        if conflict.isRemoteTombstone {
            remoteVersion = .tombstone(
                RemoteLoadoutTombstone(
                    id: conflict.loadoutID,
                    revision: conflict.remoteRevision,
                    deletedAt: conflict.remoteChangedAt
                )
            )
        } else {
            guard let data = conflict.remoteSnapshotData else {
                throw LoadoutSyncPersistenceError.invalidSyncSnapshot
            }
            remoteVersion = .aggregate(
                RemoteLoadoutAggregate(
                    projection: try decodeProjection(data),
                    revision: conflict.remoteRevision,
                    createdAt: conflict.remoteCreatedAt ?? conflict.remoteChangedAt,
                    updatedAt: conflict.remoteChangedAt
                )
            )
        }
        return LoadoutConflictSnapshot(
            id: conflict.id,
            scopeID: conflict.scopeID,
            loadoutID: conflict.loadoutID,
            baseRevision: conflict.baseRevision,
            localOperation: localIntent.operation,
            localDeleteReason: localIntent.deleteReason,
            localSnapshot: try decodeSnapshot(conflict.localSnapshotData),
            remoteVersion: remoteVersion,
            detectedAt: conflict.detectedAt
        )
    }

    private func conflictLocalIntent(
        loadoutID: UUID
    ) throws -> (
        operation: LoadoutMutationOperation,
        deleteReason: LoadoutDeleteReason?
    ) {
        let pending = try pendingChanges(loadoutID: loadoutID)
        for change in pending.reversed() {
            if let attempt = try fetchAttempt(pendingChangeID: change.id) {
                return (attempt.operation, change.deleteReason)
            }
        }
        guard let change = pending.last else {
            return (.replace, nil)
        }
        switch change.kind {
        case .delete:
            return (.delete, change.deleteReason)
        case .upsert:
            let metadata = try fetchSyncMetadata(loadoutID: loadoutID)
            return (metadata?.acknowledgedRevision == nil ? .create : .replace, nil)
        }
    }
}

// MARK: - Validation and state helpers

extension SwiftDataPersistence {
    private func validateBody(
        _ body: Data?,
        for operation: LoadoutMutationOperation
    ) throws {
        switch operation {
        case .create, .replace:
            guard let body, !body.isEmpty, body.count <= 512 * 1_024 else {
                throw LoadoutSyncPersistenceError.attemptInvariantViolation
            }
        case .delete:
            guard body == nil else {
                throw LoadoutSyncPersistenceError.attemptInvariantViolation
            }
        }
    }

    private func mutationOperation(
        for change: PendingLoadoutChange,
        revision: Int64?
    ) throws -> LoadoutMutationOperation {
        switch change.kind {
        case .upsert:
            return revision == nil ? .create : .replace
        case .delete:
            guard revision != nil else {
                throw LoadoutSyncPersistenceError.attemptInvariantViolation
            }
            return .delete
        }
    }

    private func isAttemptEligible(
        _ attempt: LoadoutMutationAttempt,
        at date: Date
    ) -> Bool {
        switch attempt.state {
        case .ready, .inFlight:
            true
        case .retryScheduled:
            attempt.retryNotBefore.map { $0 <= date } ?? true
        case .failed, .conflicted:
            false
        }
    }

    private func nextGeneration(after generation: Int64) throws -> Int64 {
        guard generation < Int64.max else {
            throw LoadoutSyncPersistenceError.attemptInvariantViolation
        }
        return generation + 1
    }

    private func validateBootstrapPage(
        scope: LoadoutSyncScope,
        cursor: Int64,
        nextAfter: UUID?,
        hasMore: Bool
    ) throws {
        guard cursor >= 0,
              !hasMore || nextAfter != nil,
              scope.bootstrapCursor == nil || scope.bootstrapCursor == cursor,
              scope.bootstrapState != .inProgress
                || nextAfter != scope.bootstrapAfter else {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
    }

    private func updateBootstrapProgress(
        _ scope: LoadoutSyncScope,
        cursor: Int64,
        nextAfter: UUID?,
        hasMore: Bool,
        appliedAt: Date
    ) {
        scope.bootstrapCursor = hasMore ? cursor : nil
        scope.bootstrapAfter = hasMore ? nextAfter : nil
        scope.bootstrapState = hasMore ? .inProgress : .complete
        scope.cursor = hasMore ? scope.cursor : cursor
        scope.lastCompletedAt = hasMore ? scope.lastCompletedAt : appliedAt
        scope.lastFailureCode = nil
        scope.updatedAt = appliedAt
    }

    private func validateChangePage(
        _ changes: [RemoteLoadoutChange],
        currentCursor: Int64?,
        nextCursor: Int64,
        hasMore: Bool
    ) throws {
        guard let currentCursor,
              nextCursor >= currentCursor,
              changes.count <= 20 else {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
        var previousCursor = currentCursor
        for change in changes {
            guard change.cursor > previousCursor,
                  change.cursor <= nextCursor else {
                throw LoadoutSyncPersistenceError.invalidSyncSnapshot
            }
            previousCursor = change.cursor
        }
        guard !hasMore || !changes.isEmpty else {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
    }

    private func markScopeCompleted(scopeID: UUID, at date: Date) throws {
        let scope = try requiredSyncScope(id: scopeID)
        scope.lastCompletedAt = date
        scope.lastFailureCode = nil
        scope.updatedAt = date
    }

    private func updateScopeFailure(scopeID: UUID, code: String) throws {
        let scope = try requiredSyncScope(id: scopeID)
        scope.lastFailureCode = code
        scope.updatedAt = .now
    }
}

// MARK: - Echo detection

extension SwiftDataPersistence {
    private func isSafeRemoteEcho(
        _ aggregate: RemoteLoadoutAggregate,
        pendingChanges: [PendingLoadoutChange]
    ) throws -> Bool {
        for pendingChange in pendingChanges {
            let snapshot = try decodeSnapshot(pendingChange.snapshotData)
            if LoadoutSyncProjection(snapshot: snapshot) == aggregate.projection {
                return true
            }
            if let attempt = try fetchAttempt(pendingChangeID: pendingChange.id),
               attempt.firstAttemptedAt != nil {
                let attemptedSnapshot = try decodeSnapshot(attempt.snapshotData)
                if LoadoutSyncProjection(snapshot: attemptedSnapshot) == aggregate.projection {
                    return true
                }
            }
        }
        return false
    }

    private func recoverySnapshot(loadoutID: UUID) throws -> LoadoutSnapshot {
        if let loadout = try fetchLoadout(id: loadoutID) {
            return try loadoutSnapshot(loadout)
        }
        if let pending = try pendingChanges(loadoutID: loadoutID).last {
            return try decodeSnapshot(pending.snapshotData)
        }
        if let attempt = try attempts(loadoutID: loadoutID).first {
            return try decodeSnapshot(attempt.snapshotData)
        }
        throw LoadoutSyncPersistenceError.invalidSyncSnapshot
    }
}

// MARK: - Snapshot storage and restoration

extension SwiftDataPersistence {
    private func encodeSnapshot(_ snapshot: LoadoutSnapshot) throws -> Data {
        try encode(snapshot)
    }

    private func decodeSnapshot(_ data: Data) throws -> LoadoutSnapshot {
        try decode(LoadoutSnapshot.self, from: data)
    }

    private func encodeProjection(_ projection: LoadoutSyncProjection) throws -> Data {
        try encode(projection)
    }

    private func decodeProjection(_ data: Data) throws -> LoadoutSyncProjection {
        try decode(LoadoutSyncProjection.self, from: data)
    }

    private func encode<Value: Encodable>(_ value: Value) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        } catch {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
    }

    private func restoreSnapshot(_ snapshot: LoadoutSnapshot) throws -> Loadout {
        if let loadout = try fetchLoadout(id: snapshot.id) {
            return loadout
        }
        let owner = try requiredProfile(id: snapshot.ownerID)
        let loadout = Loadout(
            id: snapshot.id,
            ownerID: snapshot.ownerID,
            title: snapshot.title,
            summary: snapshot.summary,
            category: snapshot.category,
            visibility: snapshot.visibility,
            status: snapshot.status,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
        loadout.owner = owner
        modelContext.insert(loadout)
        try restoreGraph(snapshot, on: loadout)
        return loadout
    }

    private func restoreGraph(
        _ snapshot: LoadoutSnapshot,
        on loadout: Loadout
    ) throws {
        loadout.publishedAt = snapshot.publishedAt
        loadout.archivedAt = snapshot.archivedAt
        try replaceTags(on: loadout, with: snapshot.tagNames, now: snapshot.updatedAt)
        try replaceItems(
            on: loadout,
            with: snapshot.items.map(recoveryItemCommand)
        )
        try replaceAssets(
            on: loadout,
            with: snapshot.assets.map(recoveryAssetCommand)
        )
        if let origin = snapshot.forkOrigin {
            loadout.forkOrigin = ForkOrigin(
                sourceLoadoutID: origin.sourceLoadoutID,
                sourceRemoteID: origin.sourceRemoteID,
                rootLoadoutID: origin.rootLoadoutID,
                sourceTitle: origin.sourceTitle,
                sourceAuthorHandle: origin.sourceAuthorHandle,
                forkedAt: origin.forkedAt
            )
        }
    }

    private func cloneSnapshotAsDraft(
        _ snapshot: LoadoutSnapshot,
        at date: Date
    ) throws -> Loadout {
        let owner = try requiredProfile(id: snapshot.ownerID)
        let clone = Loadout(
            ownerID: snapshot.ownerID,
            title: snapshot.title,
            summary: snapshot.summary,
            category: snapshot.category,
            visibility: .private,
            status: .draft,
            createdAt: date,
            updatedAt: date
        )
        clone.owner = owner
        modelContext.insert(clone)
        try replaceTags(on: clone, with: snapshot.tagNames, now: date)
        try replaceItems(on: clone, with: snapshot.items.map(clonedItemCommand))
        try replaceAssets(on: clone, with: snapshot.assets.map(clonedAssetCommand))
        clone.forkOrigin = snapshot.forkOrigin.map {
            ForkOrigin(
                sourceLoadoutID: $0.sourceLoadoutID,
                sourceRemoteID: $0.sourceRemoteID,
                rootLoadoutID: $0.rootLoadoutID,
                sourceTitle: $0.sourceTitle,
                sourceAuthorHandle: $0.sourceAuthorHandle,
                forkedAt: $0.forkedAt
            )
        }
        return clone
    }

    private func recoveryItemCommand(
        _ item: LoadoutItemSnapshot
    ) -> LoadoutItemCommand {
        LoadoutItemCommand(
            id: item.id,
            title: item.title,
            category: item.category,
            brand: item.brand,
            model: item.model,
            notes: item.notes,
            quantity: item.quantity,
            isEssential: item.isEssential,
            links: item.links.map {
                ItemLinkCommand(id: $0.id, urlString: $0.urlString, label: $0.label)
            }
        )
    }

    private func clonedItemCommand(
        _ item: LoadoutItemSnapshot
    ) -> LoadoutItemCommand {
        LoadoutItemCommand(
            title: item.title,
            category: item.category,
            brand: item.brand,
            model: item.model,
            notes: item.notes,
            quantity: item.quantity,
            isEssential: item.isEssential,
            links: item.links.map {
                ItemLinkCommand(urlString: $0.urlString, label: $0.label)
            }
        )
    }

    private func recoveryAssetCommand(
        _ asset: LoadoutAssetSnapshot
    ) -> LoadoutAssetCommand {
        LoadoutAssetCommand(
            id: asset.id,
            mediaKind: asset.mediaKind,
            caption: asset.caption,
            localFileName: asset.localFileName,
            remoteURLString: asset.remoteURLString,
            thumbnailData: asset.thumbnailData
        )
    }

    private func clonedAssetCommand(
        _ asset: LoadoutAssetSnapshot
    ) -> LoadoutAssetCommand {
        LoadoutAssetCommand(
            mediaKind: asset.mediaKind,
            caption: asset.caption,
            localFileName: asset.localFileName,
            remoteURLString: asset.remoteURLString,
            thumbnailData: asset.thumbnailData
        )
    }
}

// MARK: - Queue maintenance

extension SwiftDataPersistence {
    private func clearSyncWork(loadoutID: UUID) throws {
        for attempt in try attempts(loadoutID: loadoutID) {
            modelContext.delete(attempt)
        }
        for pendingChange in try pendingChanges(loadoutID: loadoutID) {
            modelContext.delete(pendingChange)
        }
    }

    private func syncMetadata(
        loadoutID: UUID,
        scopeID: UUID,
        at date: Date
    ) throws -> LoadoutSyncMetadata {
        if let metadata = try fetchSyncMetadata(loadoutID: loadoutID) {
            guard metadata.scopeID == nil || metadata.scopeID == scopeID else {
                throw LoadoutSyncPersistenceError.accountScopeMismatch
            }
            metadata.scopeID = scopeID
            metadata.updatedAt = date
            return metadata
        }
        let metadata = LoadoutSyncMetadata(
            loadoutID: loadoutID,
            scopeID: scopeID,
            updatedAt: date
        )
        modelContext.insert(metadata)
        return metadata
    }

    private func mappedSyncPersistenceError(_ error: Error) -> Error {
        if error is PersistenceError || error is LoadoutSyncPersistenceError {
            return error
        }
        return PersistenceError.saveFailed
    }
}
