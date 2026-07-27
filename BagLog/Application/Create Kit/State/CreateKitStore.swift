//
//  CreateKitStore.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Foundation
import Observation
import Persistence

@MainActor
@Observable
final class CreateKitStore {
    private(set) var phase = CreateKitPhase.loading
    private(set) var saveState = CreateKitSaveState.idle
    private(set) var conflict: LoadoutConflictSnapshot?
    var draft: CreateKitDraft?
    private(set) var lastInsertedItemID: UUID?
    private(set) var itemInsertionCount = 0
    private(set) var itemDeletionCount = 0
    private(set) var reorderCount = 0
    private(set) var isCreatingProfile = false
    private(set) var isImportingPhoto = false
    private(set) var isPublishing = false

    var profileDisplayName = ""
    var profileHandle = ""
    var composerText = ""
    var message: String?
    var isShowingCloseConfirmation = false
    var isShowingPublishConfirmation = false

    private let presentation: CreateKitPresentation
    private let dependencies: CreateKitDependencies
    private var debounceTask: Task<Void, Never>?
    private var committedFileNames = Set<String>()
    private var revision = 0
    private var hasPendingChanges = false
    private var isSaveInFlight = false
    private var needsResave = false

    init(
        presentation: CreateKitPresentation,
        dependencies: CreateKitDependencies
    ) {
        self.presentation = presentation
        self.dependencies = dependencies
    }

    var requiresDismissProtection: Bool {
        hasPendingChanges && draft?.hasMeaningfulContent == true
    }

    func start() async {
        guard phase == .loading else { return }

        do {
            guard let profile = try await dependencies.persistence.localProfile() else {
                phase = .needsProfile
                return
            }

            try await openEditor(for: profile)
        } catch {
            showFatalError("BagLog couldn’t open this editor. Please try again.")
        }
    }

    func retryStart() async {
        phase = .loading
        await start()
    }

    func createProfile() async throws {
        let displayName = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = profileHandle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !displayName.isEmpty else {
            message = "Enter the name people should see on your kits."
            throw CreateKitEditorError.invalidDraft(message ?? "Display name is required.")
        }

        guard !handle.isEmpty else {
            message = "Choose a short local handle."
            throw CreateKitEditorError.invalidDraft(message ?? "Handle is required.")
        }

        isCreatingProfile = true
        defer { isCreatingProfile = false }

        do {
            let profile = try await dependencies.persistence.saveProfile(
                SaveUserProfileCommand(handle: handle, displayName: displayName)
            )
            dependencies.syncDidChange()
            message = nil
            try await openEditor(for: profile)
        } catch {
            message = "BagLog couldn’t create your local profile. Try again."
            throw CreateKitEditorError.saveFailed
        }
    }

    func markTextChanged() {
        markChanged()
        cancelDebouncedSave()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.debounceTask = nil
            await self?.saveDraftIfPossible()
        }
    }

    func markStructureChanged() {
        markChanged()
        cancelDebouncedSave()
        Task { [weak self] in
            await self?.saveDraftIfPossible()
        }
    }

    func retrySave() async {
        cancelDebouncedSave()
        await saveDraftIfPossible()
    }

    func publish() async throws -> UUID {
        guard conflict == nil else {
            throw CreateKitEditorError.invalidDraft(
                "Resolve the synced versions before publishing this draft."
            )
        }
        guard let validationDraft = draft, validationDraft.canPublish else {
            throw CreateKitEditorError.invalidDraft(
                draft?.validationMessage ?? "Add at least one item before publishing."
            )
        }

        cancelDebouncedSave()
        isPublishing = true
        defer { isPublishing = false }
        await waitForActiveSave()

        guard let draft, draft.canPublish else {
            throw CreateKitEditorError.invalidDraft(
                draft?.validationMessage ?? "Add at least one item before publishing."
            )
        }
        saveState = .saving

        do {
            let snapshot = try await dependencies.persistence.saveLoadout(
                draft.command(status: .published)
            )
            await applySuccessfulSave(snapshot, revision: revision)
            return snapshot.id
        } catch {
            saveState = .failed
            message = "This kit couldn’t be published. Your draft is still here."
            throw CreateKitEditorError.saveFailed
        }
    }

    private func openEditor(for profile: UserProfileSnapshot) async throws {
        switch presentation {
        case .new:
            draft = CreateKitDraft(ownerID: profile.id)
            committedFileNames = []
        case let .edit(loadoutID):
            guard let snapshot = try await dependencies.persistence.loadout(id: loadoutID),
                  snapshot.ownerID == profile.id,
                  snapshot.status == .draft else {
                throw CreateKitEditorError.unavailableDraft
            }
            draft = CreateKitDraft(snapshot: snapshot)
            committedFileNames = Set(snapshot.assets.compactMap(\.localFileName))
            conflict = try await dependencies.syncPersistence?.conflict(
                loadoutID: snapshot.id
            )
        }

        saveState = draft?.id == nil ? .idle : .saved
        hasPendingChanges = false
        message = nil
        phase = .editing
    }

    private func markChanged() {
        revision += 1
        hasPendingChanges = true
        if saveState != .saving { saveState = .idle }
        message = draft?.validationMessage
    }

    func didInsertItem(id: UUID) {
        composerText = ""
        lastInsertedItemID = id
        itemInsertionCount += 1
        message = nil
        markStructureChanged()
    }

    func didDeleteItem() {
        itemDeletionCount += 1
        markStructureChanged()
    }

    func didReorder() {
        reorderCount += 1
        markStructureChanged()
    }

    private func saveDraftIfPossible() async {
        if isSaveInFlight {
            needsResave = true
            return
        }

        guard draft?.isValid == true,
              hasPendingChanges else { return }

        isSaveInFlight = true
        repeat {
            needsResave = false
            guard let draft,
                  draft.isValid,
                  hasPendingChanges else { break }

            saveState = .saving
            let savingRevision = revision

            do {
                let snapshot = try await dependencies.persistence.saveLoadout(
                    draft.command(status: .draft)
                )
                await applySuccessfulSave(snapshot, revision: savingRevision)
            } catch {
                saveState = .failed
                message = "Your latest changes aren’t saved yet. Tap to retry."
                needsResave = false
            }
        } while needsResave

        if hasPendingChanges, saveState == .saving {
            saveState = .idle
        }
        isSaveInFlight = false
    }

    private func applySuccessfulSave(
        _ snapshot: LoadoutSnapshot,
        revision savingRevision: Int
    ) async {
        draft?.id = snapshot.id
        dependencies.syncDidChange()
        let newCommittedFiles = Set(snapshot.assets.compactMap(\.localFileName))
        let removedFiles = committedFileNames.subtracting(newCommittedFiles)
        committedFileNames = newCommittedFiles

        if revision == savingRevision {
            hasPendingChanges = false
            saveState = .saved
            message = nil
        } else {
            needsResave = true
        }

        for fileName in removedFiles {
            do {
                try await dependencies.mediaStore.remove(fileNamed: fileName)
            } catch {
                message = "The kit saved, but an old photo couldn’t be cleaned up."
            }
        }
    }

    private func waitForActiveSave() async {
        while isSaveInFlight {
            await Task.yield()
        }
    }

    private func cancelDebouncedSave() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func showFatalError(_ text: String) {
        phase = .failed
        message = text
    }

    func refreshConflict() async {
        guard let loadoutID = draft?.id,
              let syncPersistence = dependencies.syncPersistence else {
            return
        }
        do {
            conflict = try await syncPersistence.conflict(loadoutID: loadoutID)
        } catch {
            // A background presentation refresh must not interrupt local editing.
        }
    }

    func resolveConflict(_ resolution: LoadoutConflictResolution) async {
        guard let loadoutID = draft?.id,
              let syncPersistence = dependencies.syncPersistence else {
            return
        }
        do {
            let resolved = try await syncPersistence.resolveConflict(
                loadoutID: loadoutID,
                resolution: resolution,
                at: .now
            )
            conflict = nil
            dependencies.syncDidChange()
            if let resolved {
                draft = CreateKitDraft(snapshot: resolved)
                committedFileNames = Set(resolved.assets.compactMap(\.localFileName))
                saveState = .saved
                message = nil
            } else {
                draft = nil
                phase = .failed
                message = "This draft was deleted."
            }
        } catch {
            message = "BagLog couldn’t apply that choice. Please try again."
        }
    }
}

extension CreateKitStore {
    func importPhoto(at temporaryURL: URL) async {
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        guard draft?.canAddPhoto == true else {
            message = "A kit can have up to three photos."
            return
        }

        isImportingPhoto = true
        defer { isImportingPhoto = false }
        let assetID = UUID()

        do {
            let storedFile = try await dependencies.mediaStore.importImage(
                at: temporaryURL,
                for: assetID
            )
            guard draft?.canAddPhoto == true else {
                try await dependencies.mediaStore.remove(fileNamed: storedFile.localFileName)
                return
            }

            draft?.addPhoto(
                CreateKitPhotoDraft(
                    id: assetID,
                    localFileName: storedFile.localFileName,
                    thumbnailData: storedFile.thumbnailData
                )
            )
            message = nil
            markStructureChanged()
        } catch {
            message = "That photo couldn’t be imported. Try another image."
        }
    }

    func removePhoto(id: UUID) async {
        guard let photo = draft?.removePhoto(id: id) else { return }

        if !committedFileNames.contains(photo.localFileName) {
            try? await dependencies.mediaStore.remove(fileNamed: photo.localFileName)
        }

        markStructureChanged()
    }

    func prepareToClose() async -> CreateKitCloseOutcome {
        guard let draft else { return .dismiss }
        guard draft.hasMeaningfulContent else { return .dismiss }
        guard hasPendingChanges else { return .dismiss }

        if draft.isValid {
            cancelDebouncedSave()
            await waitForActiveSave()
            await saveDraftIfPossible()
            if !hasPendingChanges { return .dismiss }
        }

        isShowingCloseConfirmation = true
        return .confirmationRequired
    }

    func retryCloseSave() async -> CreateKitCloseOutcome {
        guard draft?.isValid == true else {
            message = draft?.validationMessage
            return .confirmationRequired
        }

        await saveDraftIfPossible()
        return hasPendingChanges ? .confirmationRequired : .dismiss
    }

    func discardUnsavedChanges() async {
        cancelDebouncedSave()
        guard let draft else { return }
        let stagedFiles = Set(draft.photos.map(\.localFileName)).subtracting(committedFileNames)

        for fileName in stagedFiles {
            try? await dependencies.mediaStore.remove(fileNamed: fileName)
        }
    }
}
