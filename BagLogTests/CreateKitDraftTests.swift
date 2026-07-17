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
        let store = CreateKitStore()
        store.draft = CreateKitDraft(ownerID: UUID())
        store.composerText = "  Camera  "
        store.addComposedItem()
        store.composerText = "Water"
        store.addComposedItem()
        store.composerText = "Passport"
        store.addComposedItem()

        #expect(store.draft?.items.map(\.title) == ["Camera", "Water", "Passport"])

        let passportID = store.draft?.items[2].id
        if let passportID {
            store.moveItemUp(id: passportID)
        }
        #expect(store.draft?.items.map(\.title) == ["Camera", "Passport", "Water"])

        let cameraID = store.draft?.items[0].id
        let waterID = store.draft?.items[2].id
        if let cameraID, let waterID {
            store.moveItem(id: waterID, before: cameraID)
        }
        #expect(store.draft?.items.map(\.title) == ["Water", "Camera", "Passport"])
    }

    @Test("Photo menu movement preserves an explicit cover-first order")
    func photoReorder() {
        let store = CreateKitStore()
        var draft = CreateKitDraft(ownerID: UUID())
        draft.photos = [
            CreateKitPhotoDraft(id: UUID(), localFileName: "one.jpg", thumbnailData: Data([1])),
            CreateKitPhotoDraft(id: UUID(), localFileName: "two.jpg", thumbnailData: Data([2])),
            CreateKitPhotoDraft(id: UUID(), localFileName: "three.jpg", thumbnailData: Data([3]))
        ]
        store.draft = draft

        let firstID = draft.photos[0].id
        let thirdID = draft.photos[2].id
        store.movePhotoLater(id: firstID)
        store.movePhotoEarlier(id: thirdID)

        #expect(store.draft?.photos.map(\.localFileName) == ["two.jpg", "three.jpg", "one.jpg"])
        store.makeCover(photoID: firstID)
        #expect(store.draft?.photos.first?.localFileName == "one.jpg")
    }
}
