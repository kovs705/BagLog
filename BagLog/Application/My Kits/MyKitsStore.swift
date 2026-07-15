//
//  MyKitsStore.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Observation
import Persistence

@MainActor
@Observable
final class MyKitsStore {
    private(set) var loadouts: [LoadoutSnapshot] = []
    private(set) var isLoading = true
    private(set) var hasLoadingError = false

    func load(using persistence: (any BagLogPersisting)?) async {
        guard let persistence else {
            loadouts = []
            hasLoadingError = true
            isLoading = false
            return
        }

        isLoading = true
        hasLoadingError = false

        do {
            loadouts = try await persistence.loadouts()
        } catch {
            loadouts = []
            hasLoadingError = true
        }

        isLoading = false
    }
}
