import Foundation
import Testing
@testable import Persistence

@Suite("SwiftData persistence")
struct SwiftDataPersistenceTests {
    @Test("A loadout persists its ordered graph and reusable tags")
    func saveLoadout() async throws {
        guard #available(iOS 18.0, macOS 15.0, *) else {
            return
        }

        let persistence = try makePersistence()
        let profile = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "kovs", displayName: "Eugene")
        )

        let saved = try await persistence.saveLoadout(
            SaveLoadoutCommand(
                ownerID: profile.id,
                title: "Weekend camera bag",
                summary: "A compact travel kit.",
                category: .camera,
                tagNames: ["Travel", " travel "],
                items: [
                    LoadoutItemCommand(
                        title: "Camera",
                        quantity: 1,
                        links: [ItemLinkCommand(urlString: "https://example.com/camera")]
                    ),
                    LoadoutItemCommand(title: "Battery", quantity: 2)
                ]
            )
        )

        let loaded = try #require(await persistence.loadout(id: saved.id))
        let loadouts = try await persistence.loadouts()

        #expect(loadouts.map(\.id) == [saved.id])
        #expect(loaded.tagNames == ["Travel"])
        #expect(loaded.items.map(\.title) == ["Camera", "Battery"])
        #expect(loaded.items[0].links.map(\.urlString) == ["https://example.com/camera"])
        #expect(loaded.items.map(\.sortIndex) == [0, 1])
    }

    @Test("Forking creates independent children and keeps immutable attribution")
    func forkLoadout() async throws {
        guard #available(iOS 18.0, macOS 15.0, *) else {
            return
        }

        let persistence = try makePersistence()
        let creator = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "creator", displayName: "Creator")
        )
        let forker = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "forker", displayName: "Forker")
        )
        let source = try await persistence.saveLoadout(
            SaveLoadoutCommand(
                ownerID: creator.id,
                title: "Public travel kit",
                category: .travel,
                visibility: .public,
                status: .published,
                items: [
                    LoadoutItemCommand(
                        title: "Passport",
                        links: [ItemLinkCommand(urlString: "https://example.com/passport")]
                    )
                ],
                assets: [
                    LoadoutAssetCommand(
                        mediaKind: .image,
                        localFileName: "private-image.jpg"
                    )
                ]
            )
        )

        let fork = try await persistence.forkLoadout(
            ForkLoadoutCommand(sourceLoadoutID: source.id, ownerID: forker.id)
        )

        #expect(fork.id != source.id)
        #expect(fork.ownerID == forker.id)
        #expect(fork.visibility == .private)
        #expect(fork.status == .draft)
        #expect(fork.items[0].id != source.items[0].id)
        #expect(fork.items[0].links[0].id != source.items[0].links[0].id)
        #expect(fork.assets.isEmpty)
        #expect(fork.forkOrigin?.sourceLoadoutID == source.id)
        #expect(fork.forkOrigin?.rootLoadoutID == source.id)
        #expect(fork.forkOrigin?.sourceAuthorHandle == "creator")
    }

    @Test("Managed media stays inside the dedicated Application Support directory")
    func storeMedia() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let mediaStore = try FileMediaStore(applicationSupportDirectory: temporaryDirectory)
        let fileName = try await mediaStore.store(Data([1, 2, 3]), for: UUID(), fileExtension: "jpg")

        #expect(await mediaStore.contains(fileNamed: fileName))
        try await mediaStore.remove(fileNamed: fileName)
        #expect(await mediaStore.contains(fileNamed: fileName) == false)
    }

    private func makePersistence() throws -> SwiftDataPersistence {
        SwiftDataPersistence(modelContainer: try BagLogModelContainer.make(isStoredInMemoryOnly: true))
    }
}
