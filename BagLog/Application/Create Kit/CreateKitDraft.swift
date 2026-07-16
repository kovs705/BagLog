import Foundation
import Persistence

struct CreateKitDraft: Equatable {
    var id: UUID?
    let ownerID: UUID
    var title: String
    var summary: String
    var category: LoadoutCategory
    var tagNames: [String]
    var items: [CreateKitItemDraft]
    var photos: [CreateKitPhotoDraft]

    init(ownerID: UUID) {
        id = nil
        self.ownerID = ownerID
        title = ""
        summary = ""
        category = .other
        tagNames = []
        items = []
        photos = []
    }

    init(snapshot: LoadoutSnapshot) {
        id = snapshot.id
        ownerID = snapshot.ownerID
        title = snapshot.title
        summary = snapshot.summary
        category = snapshot.category
        tagNames = snapshot.tagNames
        items = snapshot.items.map(CreateKitItemDraft.init)
        photos = snapshot.assets
            .filter { $0.mediaKind == .image && $0.localFileName != nil }
            .prefix(3)
            .map(CreateKitPhotoDraft.init)
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && items.allSatisfy(\.isValid)
            && photos.count <= 3
    }

    var canPublish: Bool {
        isValid && !items.isEmpty
    }

    var hasMeaningfulContent: Bool {
        id != nil
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !tagNames.isEmpty
            || !items.isEmpty
            || !photos.isEmpty
    }

    var validationMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give your kit a title before it can be saved."
        }

        if let invalidItem = items.first(where: { !$0.isValid }) {
            if invalidItem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Every item needs a name."
            }

            if invalidItem.quantity < 1 {
                return "Item quantity must be at least one."
            }

            return "Links must use a complete HTTPS address."
        }

        return nil
    }

    func command(status: LoadoutStatus) -> SaveLoadoutCommand {
        SaveLoadoutCommand(
            id: id,
            ownerID: ownerID,
            title: title,
            summary: summary,
            category: category,
            visibility: status == .published ? .public : .private,
            status: status,
            tagNames: tagNames,
            items: items.map(\.command),
            assets: photos.map(\.command)
        )
    }
}
