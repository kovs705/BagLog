//
//  SwiftDataPersistence+Support.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

extension SwiftDataPersistence {
    func fetchProfile(id: UUID) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })
        do { return try modelContext.fetch(descriptor).first } catch { throw PersistenceError.queryFailed }
    }

    func requiredProfile(id: UUID) throws -> UserProfile {
        guard let profile = try fetchProfile(id: id) else { throw PersistenceError.profileNotFound(id) }
        return profile
    }

    func fetchLoadout(id: UUID) throws -> Loadout? {
        let descriptor = FetchDescriptor<Loadout>(predicate: #Predicate { $0.id == id })
        do { return try modelContext.fetch(descriptor).first } catch { throw PersistenceError.queryFailed }
    }

    func requiredLoadout(id: UUID) throws -> Loadout {
        guard let loadout = try fetchLoadout(id: id) else { throw PersistenceError.loadoutNotFound(id) }
        return loadout
    }

    func saveChanges() throws {
        do { try modelContext.save() } catch { throw PersistenceError.saveFailed }
    }

    func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    func normalizedSummary(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizedTagName(from name: String) throws -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        guard !normalizedName.isEmpty else { throw PersistenceError.invalidTagName }
        return normalizedName
    }

    func validatedURLString(_ value: String) throws -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue), url.scheme == "https", url.host != nil else { throw PersistenceError.invalidURL }
        return trimmedValue
    }

    func validateUniqueIdentifiers(_ identifiers: [UUID?]) throws {
        let identifiers = identifiers.compactMap { $0 }
        guard Set(identifiers).count == identifiers.count else { throw PersistenceError.duplicateIdentifier }
    }

    func profileSnapshot(_ profile: UserProfile) -> UserProfileSnapshot {
        UserProfileSnapshot(id: profile.id, handle: profile.handle, displayName: profile.displayName, bio: profile.bio, avatarAssetID: profile.avatarAssetID, createdAt: profile.createdAt, updatedAt: profile.updatedAt)
    }

    func loadoutSnapshot(_ loadout: Loadout) -> LoadoutSnapshot {
        LoadoutSnapshot(id: loadout.id, ownerID: loadout.ownerID, remoteID: loadout.remoteID, title: loadout.title, summary: loadout.summary, category: loadout.category, visibility: loadout.visibility, status: loadout.status, syncState: loadout.syncState, createdAt: loadout.createdAt, updatedAt: loadout.updatedAt, publishedAt: loadout.publishedAt, archivedAt: loadout.archivedAt, lastSyncedAt: loadout.lastSyncedAt, remoteRevision: loadout.remoteRevision, tagNames: loadout.tags.map(\.name).sorted(), items: loadout.items.sorted(using: KeyPathComparator(\.sortIndex)).map(itemSnapshot), assets: loadout.assets.sorted(using: KeyPathComparator(\.sortIndex)).map(assetSnapshot), forkOrigin: loadout.forkOrigin.map(forkOriginSnapshot))
    }

    func itemSnapshot(_ item: LoadoutItem) -> LoadoutItemSnapshot {
        LoadoutItemSnapshot(id: item.id, title: item.title, brand: item.brand, model: item.model, notes: item.notes, quantity: item.quantity, sortIndex: item.sortIndex, isEssential: item.isEssential, links: item.links.sorted(using: KeyPathComparator(\.sortIndex)).map(linkSnapshot))
    }

    func linkSnapshot(_ link: ItemLink) -> ItemLinkSnapshot {
        ItemLinkSnapshot(id: link.id, urlString: link.urlString, label: link.label, sortIndex: link.sortIndex)
    }

    func assetSnapshot(_ asset: LoadoutAsset) -> LoadoutAssetSnapshot {
        LoadoutAssetSnapshot(id: asset.id, mediaKind: asset.mediaKind, sortIndex: asset.sortIndex, caption: asset.caption, localFileName: asset.localFileName, remoteURLString: asset.remoteURLString, thumbnailData: asset.thumbnailData)
    }

    func forkOriginSnapshot(_ origin: ForkOrigin) -> ForkOriginSnapshot {
        ForkOriginSnapshot(sourceLoadoutID: origin.sourceLoadoutID, sourceRemoteID: origin.sourceRemoteID, rootLoadoutID: origin.rootLoadoutID, sourceTitle: origin.sourceTitle, sourceAuthorHandle: origin.sourceAuthorHandle, forkedAt: origin.forkedAt)
    }
}
