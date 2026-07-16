import Foundation
import Persistence

struct CreateKitItemDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var category: String
    var brand: String
    var model: String
    var notes: String
    var quantity: Int
    var isEssential: Bool
    var links: [CreateKitLinkDraft]

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
        category = ""
        brand = ""
        model = ""
        notes = ""
        quantity = 1
        isEssential = false
        links = []
    }

    init(snapshot: LoadoutItemSnapshot) {
        id = snapshot.id
        title = snapshot.title
        category = snapshot.category ?? ""
        brand = snapshot.brand ?? ""
        model = snapshot.model ?? ""
        notes = snapshot.notes ?? ""
        quantity = snapshot.quantity
        isEssential = snapshot.isEssential
        links = snapshot.links.map(CreateKitLinkDraft.init)
    }

    var command: LoadoutItemCommand {
        LoadoutItemCommand(
            id: id,
            title: title,
            category: category,
            brand: brand,
            model: model,
            notes: notes,
            quantity: quantity,
            isEssential: isEssential,
            links: links.map(\.command)
        )
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity > 0
            && links.allSatisfy(\.isValid)
    }
}
