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
                        category: "  Tech  ",
                        quantity: 1,
                        links: [ItemLinkCommand(urlString: "https://example.com/camera")]
                    ),
                    LoadoutItemCommand(title: "Battery", quantity: 2)
                ],
                assets: [
                    LoadoutAssetCommand(
                        mediaKind: .image,
                        localFileName: "cover.jpg",
                        thumbnailData: Data([1])
                    ),
                    LoadoutAssetCommand(
                        mediaKind: .image,
                        localFileName: "detail.jpg",
                        thumbnailData: Data([2])
                    )
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
        #expect(loaded.items[0].category == "Tech")
        #expect(loaded.assets.map(\.localFileName) == ["cover.jpg", "detail.jpg"])
        #expect(loaded.assets.map(\.sortIndex) == [0, 1])
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
                        category: "Documents",
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
        #expect(fork.items[0].category == "Documents")
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

    @Test("The first saved profile is available as the local profile")
    func localProfile() async throws {
        guard #available(iOS 18.0, macOS 15.0, *) else { return }
        let persistence = try makePersistence()

        #expect(try await persistence.localProfile() == nil)

        let saved = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: " local ", displayName: "Local User")
        )

        #expect(try await persistence.localProfile()?.id == saved.id)
        #expect(try await persistence.localProfile()?.handle == "local")
    }

    @Test("Saving an existing draft updates it explicitly without creating a duplicate")
    func updateDraft() async throws {
        guard #available(iOS 18.0, macOS 15.0, *) else { return }
        let persistence = try makePersistence()
        let profile = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "owner", displayName: "Owner")
        )
        let draft = try await persistence.saveLoadout(
            SaveLoadoutCommand(ownerID: profile.id, title: "First title")
        )

        let updated = try await persistence.saveLoadout(
            SaveLoadoutCommand(
                id: draft.id,
                ownerID: profile.id,
                title: "Updated title",
                items: [LoadoutItemCommand(title: "Water")]
            )
        )

        #expect(updated.id == draft.id)
        #expect(updated.title == "Updated title")
        #expect(try await persistence.loadouts().count == 1)
    }

    @Test("Non-HTTPS item links are rejected")
    func rejectUnsafeURL() async throws {
        guard #available(iOS 18.0, macOS 15.0, *) else { return }
        let persistence = try makePersistence()
        let profile = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "owner", displayName: "Owner")
        )

        await #expect(throws: PersistenceError.invalidURL) {
            try await persistence.saveLoadout(
                SaveLoadoutCommand(
                    ownerID: profile.id,
                    title: "Unsafe links",
                    items: [
                        LoadoutItemCommand(
                            title: "Example",
                            links: [ItemLinkCommand(urlString: "http://example.com")]
                        )
                    ]
                )
            )
        }
    }

    @Test("Image import stores a downsampled thumbnail and supports removal")
    func importImage() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let sourceURL = temporaryDirectory.appendingPathComponent("source.png")
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNG))
        try pngData.write(to: sourceURL, options: .atomic)

        let mediaStore = try FileMediaStore(applicationSupportDirectory: temporaryDirectory)
        let stored = try await mediaStore.importImage(at: sourceURL, for: UUID())

        #expect(stored.localFileName.hasSuffix(".png"))
        #expect(stored.thumbnailData.isEmpty == false)
        #expect(await mediaStore.contains(fileNamed: stored.localFileName))

        try await mediaStore.remove(fileNamed: stored.localFileName)
        #expect(await mediaStore.contains(fileNamed: stored.localFileName) == false)
    }

    private func makePersistence() throws -> SwiftDataPersistence {
        SwiftDataPersistence(modelContainer: try BagLogModelContainer.make(isStoredInMemoryOnly: true))
    }

    private static let onePixelPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
}
