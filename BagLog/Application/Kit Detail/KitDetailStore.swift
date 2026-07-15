//
//  KitDetailStore.swift
//  BagLog
//
//  Created by Codex on 15.07.2026.
//

import Foundation
import Observation
import Persistence

@MainActor
@Observable
final class KitDetailStore {
    private(set) var loadout: LoadoutSnapshot?
    private(set) var isLoading = true
    private(set) var hasLoadingError = false

    func load(id: UUID, using persistence: (any BagLogPersisting)?) async {
        guard let persistence else {
            showLoadingError()
            return
        }

        beginLoading()

        do {
            loadout = try await persistence.loadout(id: id)
        } catch {
            showLoadingError()
            return
        }

        isLoading = false
    }

    private func beginLoading() {
        isLoading = true
        hasLoadingError = false
    }

    private func showLoadingError() {
        loadout = nil
        hasLoadingError = true
        isLoading = false
    }
}
