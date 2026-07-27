import Foundation
import Persistence
import Testing
@testable import BagLog

@Suite("Create Kit drafts")
@MainActor
struct CreateKitDraftTests {
    @Test("Draft validation requires a title, positive quantities, and HTTPS links")
    func validation() {
        var draft = CreateKitDraft(ownerID: UUID())
        #expect(draft.isValid == false)

        draft.title = "Everyday carry"
        draft.items = [CreateKitItemDraft(title: "Phone")]
        #expect(draft.canPublish)

        draft.items[0].quantity = 0
        #expect(draft.isValid == false)

        draft.items[0].quantity = 1
        draft.items[0].links = [CreateKitLinkDraft(urlString: "http://example.com")]
        #expect(draft.isValid == false)

        draft.items[0].links[0].urlString = "https://example.com/phone"
        #expect(draft.canPublish)

        draft.items[0].links[0].urlString = "HTTPS://example.com/phone"
        #expect(draft.canPublish)
    }

    @Test("Tags are trimmed and duplicate names are rejected without changing order")
    func tagEditing() {
        var draft = CreateKitDraft(ownerID: UUID())

        let didAddTravel = draft.addTag("  Travel  ")
        let didAddDuplicate = draft.addTag("travel")
        let didAddCarryOn = draft.addTag("Carry-on")

        #expect(didAddTravel)
        #expect(!didAddDuplicate)
        #expect(didAddCarryOn)
        #expect(draft.tagNames == ["Travel", "Carry-on"])
    }

    @Test("Photo capacity never exceeds the domain limit")
    func photoCapacity() {
        var draft = CreateKitDraft(ownerID: UUID())

        for index in 0...CreateKitDraft.maximumPhotoCount {
            draft.addPhoto(
                CreateKitPhotoDraft(
                    id: UUID(),
                    localFileName: "\(index).jpg",
                    thumbnailData: Data([UInt8(index)])
                )
            )
        }

        #expect(draft.photos.count == CreateKitDraft.maximumPhotoCount)
        #expect(!draft.canAddPhoto)
        #expect(draft.remainingPhotoCapacity == 0)
    }

    @Test("Publishing maps every editor field and preserves order")
    func commandMapping() {
        var draft = CreateKitDraft(ownerID: UUID())
        draft.title = "  Work bag  "
        draft.summary = "Daily commute"
        draft.category = .work
        draft.tagNames = ["Office"]

        var laptop = CreateKitItemDraft(title: "Laptop")
        laptop.category = "Tech"
        laptop.brand = "Apple"
        laptop.model = "MacBook"
        laptop.quantity = 1
        laptop.isEssential = true
        laptop.links = [
            CreateKitLinkDraft(label: "Product", urlString: "https://example.com/laptop")
        ]
        draft.items = [laptop, CreateKitItemDraft(title: "Notebook")]
        draft.photos = [
            CreateKitPhotoDraft(id: UUID(), localFileName: "cover.jpg", thumbnailData: Data([1])),
            CreateKitPhotoDraft(id: UUID(), localFileName: "inside.jpg", thumbnailData: Data([2]))
        ]

        let command = draft.command(status: .published)

        #expect(command.visibility == .public)
        #expect(command.status == .published)
        #expect(command.items.map(\.title) == ["Laptop", "Notebook"])
        #expect(command.items[0].category == "Tech")
        #expect(command.items[0].links[0].urlString == "https://example.com/laptop")
        #expect(command.assets.map(\.localFileName) == ["cover.jpg", "inside.jpg"])
    }

    @Test("Keyboard focus order is scoped between the kit and item editors")
    func focusOrder() {
        var draft = CreateKitDraft(ownerID: UUID())
        var item = CreateKitItemDraft(title: "Camera")
        item.links = [CreateKitLinkDraft(urlString: "https://example.com")]
        draft.items = [item]

        let kitFields = CreateKitFocusOrder.fields(for: draft)
        let itemFields = CreateKitFocusOrder.fields(for: item)

        #expect(kitFields == [.title, .summary, .composer])
        #expect(itemFields.first == .itemTitle(item.id))
        #expect(itemFields.contains(.itemCategory(item.id)))
        #expect(itemFields.suffix(2) == [
            .linkLabel(itemID: item.id, linkID: item.links[0].id),
            .linkURL(itemID: item.id, linkID: item.links[0].id)
        ])
    }

    @Test("Composer insertion trims input and reorder operations are deterministic")
    func composerAndReorder() {
        var draft = CreateKitDraft(ownerID: UUID())
        draft.addItem(named: "  Camera  ")
        draft.addItem(named: "Water")
        draft.addItem(named: "Passport")

        #expect(draft.items.map(\.title) == ["Camera", "Water", "Passport"])

        let passportID = draft.items[2].id
        draft.moveItemUp(id: passportID)
        #expect(draft.items.map(\.title) == ["Camera", "Passport", "Water"])

        let cameraID = draft.items[0].id
        let waterID = draft.items[2].id
        draft.moveItem(id: waterID, before: cameraID)
        #expect(draft.items.map(\.title) == ["Water", "Camera", "Passport"])
    }

    @Test("Backend topic identifiers remain selectable and searchable")
    func backendTopics() throws {
        let category = LoadoutCategory(rawValue: "winter-bike-commute")
        let topic = CreateKitTopic(
            id: category.rawValue,
            title: "Winter Bike Commute",
            symbol: "snowflake",
            keywords: ["cycling", "cold weather"]
        )
        var draft = CreateKitDraft(ownerID: UUID())
        draft.category = category

        let encodedCategory = try JSONEncoder().encode(category)
        let decodedCategory = try JSONDecoder().decode(LoadoutCategory.self, from: encodedCategory)
        let catalog = CreateKitTopic.catalog(CreateKitTopic.bundled, including: category)

        #expect(draft.command(status: .draft).category.rawValue == "winter-bike-commute")
        #expect(decodedCategory == category)
        #expect(catalog.first?.category == category)
        #expect(catalog.count == CreateKitTopic.bundled.count + 1)
        #expect(CreateKitTopic.catalog(catalog, including: category).count == catalog.count)
        #expect(topic.matches("bike"))
        #expect(topic.matches("cold"))
        #expect(!topic.matches("camera"))
    }

    @Test("Photo menu movement preserves an explicit cover-first order")
    func photoReorder() {
        var draft = CreateKitDraft(ownerID: UUID())
        draft.photos = [
            CreateKitPhotoDraft(id: UUID(), localFileName: "one.jpg", thumbnailData: Data([1])),
            CreateKitPhotoDraft(id: UUID(), localFileName: "two.jpg", thumbnailData: Data([2])),
            CreateKitPhotoDraft(id: UUID(), localFileName: "three.jpg", thumbnailData: Data([3]))
        ]
        let firstID = draft.photos[0].id
        let thirdID = draft.photos[2].id
        draft.movePhotoLater(id: firstID)
        draft.movePhotoEarlier(id: thirdID)

        #expect(draft.photos.map(\.localFileName) == ["two.jpg", "three.jpg", "one.jpg"])
        draft.makeCover(photoID: firstID)
        #expect(draft.photos.first?.localFileName == "one.jpg")
    }
}
