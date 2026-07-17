import Foundation
import Observation
import Persistence

@MainActor
@Observable
final class CreateKitStore {
    private(set) var phase = CreateKitPhase.loading
    private(set) var saveState = CreateKitSaveState.idle
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

    private var dependencies: CreateKitDependencies?
    private var presentation: CreateKitPresentation?
    private var debounceTask: Task<Void, Never>?
    private var committedFileNames = Set<String>()
    private var revision = 0
    private var hasPendingChanges = false
    private var isSaveInFlight = false
    private var needsResave = false

    var canPublish: Bool {
        draft?.canPublish == true && !isPublishing
    }

    var requiresDismissProtection: Bool {
        hasPendingChanges && draft?.hasMeaningfulContent == true
    }

    var saveStateLabel: String {
        switch saveState {
        case .idle: "Draft"
        case .saving: "Saving"
        case .saved: "Saved"
        case .failed: "Not saved"
        }
    }

    func start(
        presentation: CreateKitPresentation,
        dependencies: CreateKitDependencies
    ) async {
        guard phase == .loading else { return }

        self.presentation = presentation
        self.dependencies = dependencies

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
        guard let presentation, let dependencies else {
            showFatalError("The editor is missing a required service.")
            return
        }

        phase = .loading
        await start(presentation: presentation, dependencies: dependencies)
    }

    func reportMissingDependencies() {
        showFatalError("The editor is missing a required local service.")
    }

    func createProfile() async throws {
        guard let dependencies else { throw CreateKitEditorError.missingDependency }

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

    func addComposedItem() {
        let title = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let item = CreateKitItemDraft(title: title)
        draft?.items.append(item)
        composerText = ""
        lastInsertedItemID = item.id
        itemInsertionCount += 1
        message = nil
        markStructureChanged()
    }

    func addTag(_ value: String) {
        let tag = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard draft?.tagNames.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) == false else {
            return
        }

        draft?.tagNames.append(tag)
        markStructureChanged()
    }

    func removeTag(_ tag: String) {
        draft?.tagNames.removeAll { $0 == tag }
        markStructureChanged()
    }

    func addLink(to itemID: UUID) {
        guard let itemIndex = draft?.items.firstIndex(where: { $0.id == itemID }) else { return }
        draft?.items[itemIndex].links.append(CreateKitLinkDraft())
        markStructureChanged()
    }

    func removeLink(id linkID: UUID, from itemID: UUID) {
        guard let itemIndex = draft?.items.firstIndex(where: { $0.id == itemID }) else { return }
        draft?.items[itemIndex].links.removeAll { $0.id == linkID }
        markStructureChanged()
    }

    func removeItem(id: UUID) {
        draft?.items.removeAll { $0.id == id }
        itemDeletionCount += 1
        markStructureChanged()
    }

    func moveItemUp(id: UUID) {
        guard let index = draft?.items.firstIndex(where: { $0.id == id }), index > 0 else { return }
        draft?.items.swapAt(index, index - 1)
        didReorder()
    }

    func moveItemDown(id: UUID) {
        guard let items = draft?.items,
              let index = items.firstIndex(where: { $0.id == id }),
              index < items.index(before: items.endIndex) else { return }
        draft?.items.swapAt(index, index + 1)
        didReorder()
    }

    func moveItem(id: UUID, before targetID: UUID) {
        guard id != targetID,
              var items = draft?.items,
              let sourceIndex = items.firstIndex(where: { $0.id == id }),
              let targetIndex = items.firstIndex(where: { $0.id == targetID }) else { return }

        let originalOrder = items.map(\.id)
        let item = items.remove(at: sourceIndex)
        let destination = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        items.insert(item, at: destination)
        guard items.map(\.id) != originalOrder else { return }
        draft?.items = items
        didReorder()
    }

    func importPhoto(at temporaryURL: URL) async {
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        guard let dependencies else {
            message = "The photo service is unavailable."
            return
        }
        guard (draft?.photos.count ?? 0) < 3 else {
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
            guard (draft?.photos.count ?? 0) < 3 else {
                try await dependencies.mediaStore.remove(fileNamed: storedFile.localFileName)
                return
            }

            draft?.photos.append(
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

    func makeCover(photoID: UUID) {
        guard var photos = draft?.photos,
              let index = photos.firstIndex(where: { $0.id == photoID }),
              index != photos.startIndex else { return }
        let photo = photos.remove(at: index)
        photos.insert(photo, at: photos.startIndex)
        draft?.photos = photos
        didReorder()
    }

    func movePhotoEarlier(id: UUID) {
        guard let index = draft?.photos.firstIndex(where: { $0.id == id }), index > 0 else { return }
        draft?.photos.swapAt(index, index - 1)
        didReorder()
    }

    func movePhotoLater(id: UUID) {
        guard let photos = draft?.photos,
              let index = photos.firstIndex(where: { $0.id == id }),
              index < photos.index(before: photos.endIndex) else { return }
        draft?.photos.swapAt(index, index + 1)
        didReorder()
    }

    func movePhoto(id: UUID, before targetID: UUID) {
        guard id != targetID,
              var photos = draft?.photos,
              let sourceIndex = photos.firstIndex(where: { $0.id == id }),
              let targetIndex = photos.firstIndex(where: { $0.id == targetID }) else { return }
        let originalOrder = photos.map(\.id)
        let photo = photos.remove(at: sourceIndex)
        let destination = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        photos.insert(photo, at: destination)
        guard photos.map(\.id) != originalOrder else { return }
        draft?.photos = photos
        didReorder()
    }

    func removePhoto(id: UUID) async {
        guard let photo = draft?.photos.first(where: { $0.id == id }),
              let dependencies else { return }

        draft?.photos.removeAll { $0.id == id }

        if !committedFileNames.contains(photo.localFileName) {
            try? await dependencies.mediaStore.remove(fileNamed: photo.localFileName)
        }

        markStructureChanged()
    }

    func requestPublish() {
        guard let draft else { return }
        guard draft.canPublish else {
            message = draft.validationMessage ?? "Add at least one item before publishing."
            return
        }

        message = nil
        isShowingPublishConfirmation = true
    }

    func publish() async throws -> UUID {
        guard let dependencies else {
            throw CreateKitEditorError.missingDependency
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
        guard let dependencies, let draft else { return }
        let stagedFiles = Set(draft.photos.map(\.localFileName)).subtracting(committedFileNames)

        for fileName in stagedFiles {
            try? await dependencies.mediaStore.remove(fileNamed: fileName)
        }
    }

    private func openEditor(for profile: UserProfileSnapshot) async throws {
        guard let presentation, let dependencies else {
            throw CreateKitEditorError.missingDependency
        }

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

    private func didReorder() {
        reorderCount += 1
        markStructureChanged()
    }

    private func saveDraftIfPossible() async {
        if isSaveInFlight {
            needsResave = true
            return
        }

        guard dependencies != nil,
              draft?.isValid == true,
              hasPendingChanges else { return }

        isSaveInFlight = true
        repeat {
            needsResave = false
            guard let dependencies,
                  let draft,
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

        guard let mediaStore = dependencies?.mediaStore else { return }
        for fileName in removedFiles {
            do {
                try await mediaStore.remove(fileNamed: fileName)
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
}
