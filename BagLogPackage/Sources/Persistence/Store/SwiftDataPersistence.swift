//
//  SwiftDataPersistence.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

public enum PersistenceError: Error, Equatable, Sendable {
    case invalidHandle
    case invalidDisplayName
    case invalidLoadoutTitle
    case invalidItemTitle
    case invalidQuantity
    case invalidTagName
    case invalidURL
    case duplicateIdentifier
    case profileNotFound(UUID)
    case loadoutNotFound(UUID)
    case ownerCannotChange
    case sourceIsNotPublic
    case saveFailed
    case queryFailed
}

public protocol BagLogPersisting: Sendable {
    func profile(id: UUID) async throws -> UserProfileSnapshot?
    func saveProfile(_ command: SaveUserProfileCommand) async throws -> UserProfileSnapshot
    func loadout(id: UUID) async throws -> LoadoutSnapshot?
    func loadouts() async throws -> [LoadoutSnapshot]
    func loadouts(ownerID: UUID) async throws -> [LoadoutSnapshot]
    func saveLoadout(_ command: SaveLoadoutCommand) async throws -> LoadoutSnapshot
    func forkLoadout(_ command: ForkLoadoutCommand) async throws -> LoadoutSnapshot
    func deleteLoadout(id: UUID) async throws
}

public actor SwiftDataPersistence: BagLogPersisting {
    let modelContext: ModelContext

    public init(modelContainer: ModelContainer) {
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
    }

    public func profile(id: UUID) throws -> UserProfileSnapshot? {
        try fetchProfile(id: id).map(profileSnapshot)
    }

    public func saveProfile(_ command: SaveUserProfileCommand) throws -> UserProfileSnapshot {
        let values = try validatedProfileValues(from: command)
        let now = Date.now
        let profile = try profileToSave(for: command, values: values, now: now)

        try saveChanges()
        return profileSnapshot(profile)
    }

    public func loadout(id: UUID) throws -> LoadoutSnapshot? {
        try fetchLoadout(id: id).map(loadoutSnapshot)
    }

    public func loadouts() throws -> [LoadoutSnapshot] {
        let descriptor = FetchDescriptor<Loadout>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try loadoutSnapshots(matching: descriptor)
    }

    public func loadouts(ownerID: UUID) throws -> [LoadoutSnapshot] {
        let descriptor = FetchDescriptor<Loadout>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try loadoutSnapshots(matching: descriptor)
    }

    public func saveLoadout(_ command: SaveLoadoutCommand) throws -> LoadoutSnapshot {
        try validate(command)

        let now = Date.now
        let loadout = try loadoutToSave(for: command, now: now)
        apply(command, to: loadout, now: now)
        try replaceTags(on: loadout, with: command.tagNames, now: now)
        try replaceItems(on: loadout, with: command.items)
        try replaceAssets(on: loadout, with: command.assets)

        try saveChanges()
        return loadoutSnapshot(loadout)
    }

    public func forkLoadout(_ command: ForkLoadoutCommand) throws -> LoadoutSnapshot {
        let source = try requiredLoadout(id: command.sourceLoadoutID)
        guard source.visibility == .public, source.status == .published else {
            throw PersistenceError.sourceIsNotPublic
        }

        let owner = try requiredProfile(id: command.ownerID)
        let now = Date.now
        let fork = Loadout(
            ownerID: owner.id,
            title: try forkTitle(from: command, source: source),
            summary: source.summary,
            category: source.category,
            visibility: .private,
            status: .draft,
            createdAt: now,
            updatedAt: now
        )
        fork.owner = owner
        fork.tags = source.tags
        fork.items = source.items
            .sorted(using: KeyPathComparator(\.sortIndex))
            .enumerated()
            .map(cloneItem)
        fork.assets = source.assets
            .sorted(using: KeyPathComparator(\.sortIndex))
            .enumerated()
            .compactMap(cloneAsset)
        fork.forkOrigin = ForkOrigin(
            sourceLoadoutID: source.id,
            sourceRemoteID: source.remoteID,
            rootLoadoutID: source.forkOrigin?.rootLoadoutID ?? source.id,
            sourceTitle: source.title,
            sourceAuthorHandle: source.owner?.handle ?? "unknown",
            forkedAt: now
        )

        modelContext.insert(fork)
        try saveChanges()
        return loadoutSnapshot(fork)
    }

    public func deleteLoadout(id: UUID) throws {
        modelContext.delete(try requiredLoadout(id: id))
        try saveChanges()
    }
}
