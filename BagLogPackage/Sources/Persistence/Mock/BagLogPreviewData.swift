//
//  BagLogPreviewData.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import SwiftData

#if DEBUG

public enum BagLogPreviewData {
    @MainActor public static func makeModelContainer() -> ModelContainer {
        do {
            let modelContainer = try BagLogModelContainer.make(isStoredInMemoryOnly: true)
            let modelContext = ModelContext(modelContainer)
            seed(modelContext)
            try modelContext.save()
            return modelContainer
        } catch {
            fatalError("BagLog could not create preview data: \(error)")
        }
    }

    @MainActor private static func seed(_ modelContext: ModelContext) {
        let profile = UserProfile(handle: "eugene", displayName: "Eugene")
        modelContext.insert(profile)

        for loadout in Loadout.previewSamples(ownerID: profile.id) {
            modelContext.insert(loadout)
            for item in loadout.items {
                modelContext.insert(item)
            }
        }
    }
}

#endif
