//
//  SwiftDataPersistence+Loadouts.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

extension SwiftDataPersistence {
    func loadoutToSave(for command: SaveLoadoutCommand, now: Date) throws -> Loadout {
        guard let id = command.id else {
            let owner = try requiredProfile(id: command.ownerID)
            let loadout = Loadout(ownerID: owner.id, title: command.title.trimmingCharacters(in: .whitespacesAndNewlines), summary: normalizedSummary(command.summary), category: command.category, visibility: command.visibility, status: command.status, createdAt: now, updatedAt: now)
            loadout.owner = owner
            modelContext.insert(loadout)
            return loadout
        }
        let loadout = try requiredLoadout(id: id)
        guard loadout.ownerID == command.ownerID else { throw PersistenceError.ownerCannotChange }
        return loadout
    }

    func apply(_ command: SaveLoadoutCommand, to loadout: Loadout, now: Date) {
        loadout.title = command.title.trimmingCharacters(in: .whitespacesAndNewlines)
        loadout.summary = normalizedSummary(command.summary)
        loadout.category = command.category
        loadout.visibility = command.visibility
        loadout.status = command.status
        loadout.updatedAt = now
        loadout.syncState = command.status == .published ? .pendingUpload : .local
        if command.status == .published, loadout.publishedAt == nil { loadout.publishedAt = now }
        loadout.archivedAt = command.status == .archived ? now : nil
    }

    func replaceTags(on loadout: Loadout, with names: [String], now: Date) throws {
        var tags: [Tag] = []
        var normalizedNames = Set<String>()
        for name in names {
            let normalizedName = try normalizedTagName(from: name)
            guard normalizedNames.insert(normalizedName).inserted else { continue }
            tags.append(try tag(named: name, normalizedName: normalizedName, now: now))
        }
        loadout.tags = tags
    }

    func tag(named name: String, normalizedName: String, now: Date) throws -> Tag {
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.normalizedName == normalizedName })
        do {
            if let tag = try modelContext.fetch(descriptor).first { return tag }
        } catch { throw PersistenceError.queryFailed }
        let tag = Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines), normalizedName: normalizedName, createdAt: now, updatedAt: now)
        modelContext.insert(tag)
        return tag
    }

    func replaceItems(on loadout: Loadout, with commands: [LoadoutItemCommand]) throws {
        try validateUniqueIdentifiers(commands.map(\.id))
        let existingItems = Dictionary(uniqueKeysWithValues: loadout.items.map { ($0.id, $0) })
        let requestedIdentifiers = Set(commands.compactMap(\.id))
        for item in loadout.items where !requestedIdentifiers.contains(item.id) { modelContext.delete(item) }
        var items: [LoadoutItem] = []
        for (index, command) in commands.enumerated() {
            let item = existingItems[command.id ?? UUID()] ?? makeItem(from: command, sortIndex: index)
            update(item, from: command, sortIndex: index)
            try replaceLinks(on: item, with: command.links)
            items.append(item)
        }
        loadout.items = items
    }

    func makeItem(from command: LoadoutItemCommand, sortIndex: Int) -> LoadoutItem {
        LoadoutItem(
            id: command.id ?? UUID(),
            title: command.title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: normalizedOptionalText(command.category),
            brand: normalizedOptionalText(command.brand),
            model: normalizedOptionalText(command.model),
            notes: normalizedOptionalText(command.notes),
            quantity: command.quantity,
            sortIndex: sortIndex,
            isEssential: command.isEssential
        )
    }

    func update(_ item: LoadoutItem, from command: LoadoutItemCommand, sortIndex: Int) {
        item.title = command.title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = normalizedOptionalText(command.category)
        item.brand = normalizedOptionalText(command.brand)
        item.model = normalizedOptionalText(command.model)
        item.notes = normalizedOptionalText(command.notes)
        item.quantity = command.quantity
        item.sortIndex = sortIndex
        item.isEssential = command.isEssential
    }

    func replaceLinks(on item: LoadoutItem, with commands: [ItemLinkCommand]) throws {
        try validateUniqueIdentifiers(commands.map(\.id))
        let existingLinks = Dictionary(uniqueKeysWithValues: item.links.map { ($0.id, $0) })
        let requestedIdentifiers = Set(commands.compactMap(\.id))
        for link in item.links where !requestedIdentifiers.contains(link.id) { modelContext.delete(link) }
        var links: [ItemLink] = []
        for (index, command) in commands.enumerated() {
            let link = existingLinks[command.id ?? UUID()] ?? ItemLink(id: command.id ?? UUID(), urlString: command.urlString, label: command.label, sortIndex: index)
            link.urlString = try validatedURLString(command.urlString)
            link.label = normalizedOptionalText(command.label)
            link.sortIndex = index
            links.append(link)
        }
        item.links = links
    }

    func replaceAssets(on loadout: Loadout, with commands: [LoadoutAssetCommand]) throws {
        try validateUniqueIdentifiers(commands.map(\.id))
        let existingAssets = Dictionary(uniqueKeysWithValues: loadout.assets.map { ($0.id, $0) })
        let requestedIdentifiers = Set(commands.compactMap(\.id))
        for asset in loadout.assets where !requestedIdentifiers.contains(asset.id) { modelContext.delete(asset) }
        var assets: [LoadoutAsset] = []
        for (index, command) in commands.enumerated() {
            let asset = existingAssets[command.id ?? UUID()] ?? LoadoutAsset(id: command.id ?? UUID(), mediaKind: command.mediaKind, sortIndex: index)
            asset.mediaKind = command.mediaKind
            asset.sortIndex = index
            asset.caption = normalizedOptionalText(command.caption)
            asset.localFileName = normalizedOptionalText(command.localFileName)
            asset.remoteURLString = try command.remoteURLString.map(validatedURLString)
            asset.thumbnailData = command.thumbnailData
            assets.append(asset)
        }
        loadout.assets = assets
    }

    func validate(_ command: SaveLoadoutCommand) throws {
        guard !command.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PersistenceError.invalidLoadoutTitle }
        for item in command.items {
            guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PersistenceError.invalidItemTitle }
            guard item.quantity > 0 else { throw PersistenceError.invalidQuantity }
        }
    }

    func forkTitle(from command: ForkLoadoutCommand, source: Loadout) throws -> String {
        let title = (command.title ?? source.title).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw PersistenceError.invalidLoadoutTitle }
        return title
    }

    func cloneItem(_ entry: EnumeratedSequence<[LoadoutItem]>.Element) -> LoadoutItem {
        let (index, source) = entry
        let item = LoadoutItem(
            title: source.title,
            category: source.category,
            brand: source.brand,
            model: source.model,
            notes: source.notes,
            quantity: source.quantity,
            sortIndex: index,
            isEssential: source.isEssential
        )
        item.links = source.links.sorted(using: KeyPathComparator(\.sortIndex)).enumerated().map { index, source in
            ItemLink(urlString: source.urlString, label: source.label, sortIndex: index)
        }
        return item
    }

    func cloneAsset(_ entry: EnumeratedSequence<[LoadoutAsset]>.Element) -> LoadoutAsset? {
        let (index, source) = entry
        guard let remoteURLString = source.remoteURLString else { return nil }
        return LoadoutAsset(mediaKind: source.mediaKind, sortIndex: index, caption: source.caption, remoteURLString: remoteURLString)
    }
}
