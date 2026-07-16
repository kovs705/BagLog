import Foundation
import Persistence
import Testing
@testable import BagLog

@Suite("Create Kit store")
@MainActor
struct CreateKitStoreTests {
    @Test("A missing local profile gates the editor, then profile creation opens it")
    func profileGate() async throws {
        let persistence = EditorPersistenceSpy(profile: nil)
        let store = CreateKitStore()
        await store.start(
            presentation: .new,
            dependencies: dependencies(persistence: persistence)
        )

        #expect(store.phase == .needsProfile)

        store.profileDisplayName = "Eugene"
        store.profileHandle = "kovs"
        try await store.createProfile()

        let profileID = await persistence.currentProfile()?.id
        #expect(store.phase == .editing)
        #expect(store.draft?.ownerID == profileID)
    }

    @Test("Text changes coalesce into one save after 600 milliseconds")
    func debouncedSaving() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile())
        let store = try await startedStore(persistence: persistence)

        store.draft?.title = "W"
        store.markTextChanged()
        store.draft?.title = "Work"
        store.markTextChanged()
        store.draft?.title = "Work bag"
        store.markTextChanged()

        try await Task.sleep(for: .milliseconds(750))

        let commands = await persistence.savedCommands()
        #expect(commands.count == 1)
        #expect(commands.first?.title == "Work bag")
        #expect(store.saveState == .saved)
    }

    @Test("An edit made during a save triggers exactly one follow-up save")
    func editDuringSave() async throws {
        let persistence = EditorPersistenceSpy(
            profile: makeProfile(),
            saveDelay: .milliseconds(180)
        )
        let store = try await startedStore(persistence: persistence)

        store.draft?.title = "Travel"
        store.markStructureChanged()
        try await Task.sleep(for: .milliseconds(40))
        store.draft?.summary = "Updated while saving"
        store.markStructureChanged()

        try await Task.sleep(for: .milliseconds(440))

        let commands = await persistence.savedCommands()
        #expect(commands.count == 2)
        #expect(commands.last?.summary == "Updated while saving")
        #expect(store.saveState == .saved)
    }

    @Test("A failed save is actionable and retry restores Saved state")
    func retryFailedSave() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile(), failuresRemaining: 1)
        let store = try await startedStore(persistence: persistence)

        store.draft?.title = "Camera bag"
        store.markStructureChanged()
        try await Task.sleep(for: .milliseconds(40))

        #expect(store.saveState == .failed)
        await store.retrySave()

        #expect(await persistence.savedCommands().count == 2)
        #expect(store.saveState == .saved)
    }

    @Test("Invalid pending work requires an explicit close decision")
    func invalidClose() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile())
        let store = try await startedStore(persistence: persistence)
        store.draft?.title = "Cycling"
        store.markStructureChanged()
        try await Task.sleep(for: .milliseconds(40))

        var invalidItem = CreateKitItemDraft(title: "Helmet")
        invalidItem.quantity = 0
        store.draft?.items.append(invalidItem)
        store.markStructureChanged()

        #expect(await store.prepareToClose() == .confirmationRequired)
        #expect(store.isShowingCloseConfirmation)
    }

    @Test("Publishing produces a local public, read-only snapshot")
    func publish() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile())
        let store = try await startedStore(persistence: persistence)
        store.draft?.title = "Published kit"
        store.draft?.items = [CreateKitItemDraft(title: "Wallet")]

        let loadoutID = try await store.publish()
        let command = try #require(await persistence.savedCommands().last)
        let persistedLoadoutID = await persistence.lastLoadoutID()

        #expect(loadoutID == persistedLoadoutID)
        #expect(command.status == .published)
        #expect(command.visibility == .public)
    }

    @Test("Publishing waits for an active first save and reuses its identifier")
    func publishDuringInitialSave() async throws {
        let persistence = EditorPersistenceSpy(
            profile: makeProfile(),
            saveDelay: .milliseconds(120)
        )
        let store = try await startedStore(persistence: persistence)
        store.draft?.title = "Fast publish"
        store.draft?.items = [CreateKitItemDraft(title: "Keys")]
        store.markStructureChanged()
        try await Task.sleep(for: .milliseconds(20))

        let publishedID = try await store.publish()
        let commands = await persistence.savedCommands()

        #expect(commands.count == 2)
        #expect(commands[0].id == nil)
        #expect(commands[1].id == publishedID)
        #expect(commands[1].status == .published)
    }

    @Test("Discard removes staged photos that were never committed")
    func discardStagedPhoto() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile())
        let mediaStore = EditorMediaStoreSpy()
        let store = CreateKitStore()
        await store.start(
            presentation: .new,
            dependencies: CreateKitDependencies(
                persistence: persistence,
                mediaStore: mediaStore
            )
        )

        await store.importPhoto(at: URL(fileURLWithPath: "/tmp/staged.png"))
        let fileName = try #require(store.draft?.photos.first?.localFileName)
        await store.discardUnsavedChanges()

        #expect(await mediaStore.removedFileNames() == [fileName])
    }

    @Test("A committed photo is deleted only after its removal saves")
    func removeCommittedPhoto() async throws {
        let persistence = EditorPersistenceSpy(profile: makeProfile())
        let mediaStore = EditorMediaStoreSpy()
        let store = CreateKitStore()
        await store.start(
            presentation: .new,
            dependencies: CreateKitDependencies(
                persistence: persistence,
                mediaStore: mediaStore
            )
        )
        store.draft?.title = "Photo kit"

        await store.importPhoto(at: URL(fileURLWithPath: "/tmp/committed.png"))
        try await Task.sleep(for: .milliseconds(50))
        let photoID = try #require(store.draft?.photos.first?.id)
        #expect(store.saveState == .saved)

        await store.removePhoto(id: photoID)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await mediaStore.removedFileNames().count == 1)
        #expect(store.saveState == .saved)
    }

    private func startedStore(persistence: EditorPersistenceSpy) async throws -> CreateKitStore {
        let store = CreateKitStore()
        await store.start(
            presentation: .new,
            dependencies: dependencies(persistence: persistence)
        )
        #expect(store.phase == .editing)
        return store
    }

    private func dependencies(persistence: EditorPersistenceSpy) -> CreateKitDependencies {
        CreateKitDependencies(
            persistence: persistence,
            mediaStore: EditorMediaStoreSpy()
        )
    }
}

private actor EditorPersistenceSpy: BagLogPersisting {
    private var profile: UserProfileSnapshot?
    private var commands: [SaveLoadoutCommand] = []
    private let saveDelay: Duration?
    private var failuresRemaining: Int
    private var loadoutID = UUID()

    init(
        profile: UserProfileSnapshot?,
        saveDelay: Duration? = nil,
        failuresRemaining: Int = 0
    ) {
        self.profile = profile
        self.saveDelay = saveDelay
        self.failuresRemaining = failuresRemaining
    }

    func localProfile() -> UserProfileSnapshot? { profile }
    func profile(id: UUID) -> UserProfileSnapshot? { profile?.id == id ? profile : nil }

    func saveProfile(_ command: SaveUserProfileCommand) -> UserProfileSnapshot {
        let snapshot = makeProfile(
            id: command.id ?? UUID(),
            handle: command.handle,
            displayName: command.displayName
        )
        profile = snapshot
        return snapshot
    }

    func loadout(id: UUID) -> LoadoutSnapshot? { nil }
    func loadouts() -> [LoadoutSnapshot] { [] }
    func loadouts(ownerID: UUID) -> [LoadoutSnapshot] { [] }

    func saveLoadout(_ command: SaveLoadoutCommand) async throws -> LoadoutSnapshot {
        commands.append(command)
        if let saveDelay {
            try await Task.sleep(for: saveDelay)
        }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw PersistenceError.saveFailed
        }
        if let commandID = command.id {
            loadoutID = commandID
        }
        return makeLoadoutSnapshot(id: loadoutID, command: command)
    }

    func forkLoadout(_ command: ForkLoadoutCommand) throws -> LoadoutSnapshot {
        throw PersistenceError.loadoutNotFound(command.sourceLoadoutID)
    }

    func deleteLoadout(id: UUID) {}

    func savedCommands() -> [SaveLoadoutCommand] { commands }
    func currentProfile() -> UserProfileSnapshot? { profile }
    func lastLoadoutID() -> UUID { loadoutID }
}

private actor EditorMediaStoreSpy: MediaStoring {
    private var removed: [String] = []

    func importImage(at sourceURL: URL, for assetID: UUID) -> StoredMediaFile {
        StoredMediaFile(
            localFileName: "\(assetID.uuidString.lowercased()).png",
            thumbnailData: Data([1, 2, 3])
        )
    }

    func store(_ data: Data, for assetID: UUID, fileExtension: String) -> String {
        "\(assetID.uuidString.lowercased()).\(fileExtension)"
    }

    func remove(fileNamed fileName: String) {
        removed.append(fileName)
    }

    func contains(fileNamed fileName: String) -> Bool { false }
    func removedFileNames() -> [String] { removed }
}

private func makeProfile(
    id: UUID = UUID(),
    handle: String = "owner",
    displayName: String = "Owner"
) -> UserProfileSnapshot {
    UserProfileSnapshot(
        id: id,
        handle: handle,
        displayName: displayName,
        bio: nil,
        avatarAssetID: nil,
        createdAt: .now,
        updatedAt: .now
    )
}

private func makeLoadoutSnapshot(
    id: UUID,
    command: SaveLoadoutCommand
) -> LoadoutSnapshot {
    let now = Date.now
    return LoadoutSnapshot(
        id: id,
        ownerID: command.ownerID,
        remoteID: nil,
        title: command.title,
        summary: command.summary,
        category: command.category,
        visibility: command.visibility,
        status: command.status,
        syncState: .local,
        createdAt: now,
        updatedAt: now,
        publishedAt: command.status == .published ? now : nil,
        archivedAt: nil,
        lastSyncedAt: nil,
        remoteRevision: nil,
        tagNames: command.tagNames,
        items: command.items.enumerated().map { index, item in
            LoadoutItemSnapshot(
                id: item.id ?? UUID(),
                title: item.title,
                category: item.category,
                brand: item.brand,
                model: item.model,
                notes: item.notes,
                quantity: item.quantity,
                sortIndex: index,
                isEssential: item.isEssential,
                links: item.links.enumerated().map { linkIndex, link in
                    ItemLinkSnapshot(
                        id: link.id ?? UUID(),
                        urlString: link.urlString,
                        label: link.label,
                        sortIndex: linkIndex
                    )
                }
            )
        },
        assets: command.assets.enumerated().map { index, asset in
            LoadoutAssetSnapshot(
                id: asset.id ?? UUID(),
                mediaKind: asset.mediaKind,
                sortIndex: index,
                caption: asset.caption,
                localFileName: asset.localFileName,
                remoteURLString: asset.remoteURLString,
                thumbnailData: asset.thumbnailData
            )
        },
        forkOrigin: nil
    )
}
