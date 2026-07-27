//
//  PersistenceSchema.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

public enum BagLogSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            BagLogSchemaV1.UserProfile.self,
            BagLogSchemaV1.Loadout.self,
            BagLogSchemaV1.LoadoutItem.self,
            BagLogSchemaV1.ItemLink.self,
            BagLogSchemaV1.LoadoutAsset.self,
            BagLogSchemaV1.Tag.self,
            BagLogSchemaV1.ForkOrigin.self,
            BagLogSchemaV1.SavedLoadout.self
        ]
    }
}

public enum BagLogSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            BagLogSchemaV2.UserProfile.self,
            BagLogSchemaV2.Loadout.self,
            BagLogSchemaV2.LoadoutItem.self,
            BagLogSchemaV2.ItemLink.self,
            BagLogSchemaV2.LoadoutAsset.self,
            BagLogSchemaV2.Tag.self,
            BagLogSchemaV2.ForkOrigin.self,
            BagLogSchemaV2.SavedLoadout.self,
            BagLogSchemaV2.LoadoutSyncScope.self,
            BagLogSchemaV2.LoadoutSyncMetadata.self,
            BagLogSchemaV2.PendingLoadoutChange.self,
            BagLogSchemaV2.LoadoutMutationAttempt.self,
            BagLogSchemaV2.LoadoutConflict.self
        ]
    }
}

public enum BagLogSchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(3, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            Loadout.self,
            LoadoutItem.self,
            ItemLink.self,
            LoadoutAsset.self,
            Tag.self,
            ForkOrigin.self,
            SavedLoadout.self,
            LoadoutSyncScope.self,
            LoadoutSyncMetadata.self,
            PendingLoadoutChange.self,
            LoadoutMutationAttempt.self,
            LoadoutConflict.self
        ]
    }
}

public enum BagLogMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BagLogSchemaV1.self, BagLogSchemaV2.self, BagLogSchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: BagLogSchemaV1.self,
                toVersion: BagLogSchemaV2.self,
                willMigrate: nil,
                didMigrate: migrateLegacyRemoteRevisions
            ),
            .lightweight(
                fromVersion: BagLogSchemaV2.self,
                toVersion: BagLogSchemaV3.self
            )
        ]
    }

    private static func migrateLegacyRemoteRevisions(context: ModelContext) throws {
        let loadouts = try context.fetch(
            FetchDescriptor<BagLogSchemaV2.Loadout>()
        )
        for loadout in loadouts {
            guard let legacyRevision = loadout.remoteRevision else {
                continue
            }

            if let revision = Int64(legacyRevision), revision > 0 {
                context.insert(
                    BagLogSchemaV2.LoadoutSyncMetadata(
                        loadoutID: loadout.id,
                        scopeID: nil,
                        acknowledgedRevision: revision,
                        updatedAt: loadout.updatedAt
                    )
                )
            }
            loadout.remoteRevision = nil
        }
        try context.save()
    }
}

public enum BagLogModelContainer {
    // SwiftData mutates versioned-model metadata during container construction.
    // Serializing this short initialization step avoids schema checksum races.
    private static let schemaConstructionLock = NSLock()

    public static func make(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        try withSchemaConstructionLock {
            let schema = Schema(versionedSchema: BagLogSchemaV3.self)
            let configuration = if let storeURL {
                ModelConfiguration("BagLog", schema: schema, url: storeURL)
            } else {
                ModelConfiguration(
                    "BagLog",
                    schema: schema,
                    isStoredInMemoryOnly: isStoredInMemoryOnly
                )
            }

            return try ModelContainer(
                for: schema,
                migrationPlan: BagLogMigrationPlan.self,
                configurations: [configuration]
            )
        }
    }

    static func withSchemaConstructionLock<Result>(
        _ operation: () throws -> Result
    ) rethrows -> Result {
        schemaConstructionLock.lock()
        defer { schemaConstructionLock.unlock() }
        return try operation()
    }
}
