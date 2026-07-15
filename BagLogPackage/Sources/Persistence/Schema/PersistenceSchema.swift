//
//  PersistenceSchema.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import SwiftData

public enum BagLogSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
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
            SavedLoadout.self
        ]
    }
}

public enum BagLogMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [BagLogSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}

public enum BagLogModelContainer {
    public static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: BagLogSchemaV1.self)
        let configuration = ModelConfiguration(
            "BagLog",
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: BagLogMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
