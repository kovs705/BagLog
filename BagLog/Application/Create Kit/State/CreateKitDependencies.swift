//
//  CreateKitDependencies.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Persistence

struct CreateKitDependencies {
    let persistence: any BagLogPersisting
    let syncPersistence: (any BagLogSyncPersisting)?
    let mediaStore: any MediaStoring
    let syncDidChange: @MainActor () -> Void

    init(
        persistence: any BagLogPersisting,
        mediaStore: any MediaStoring,
        syncDidChange: @escaping @MainActor () -> Void = {}
    ) {
        self.persistence = persistence
        syncPersistence = persistence as? any BagLogSyncPersisting
        self.mediaStore = mediaStore
        self.syncDidChange = syncDidChange
    }
}
