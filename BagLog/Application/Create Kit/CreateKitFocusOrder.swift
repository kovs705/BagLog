struct CreateKitFocusOrder {
    static func fields(for draft: CreateKitDraft?) -> [CreateKitFocusField] {
        guard draft != nil else {
            return [.profileDisplayName, .profileHandle]
        }

        return [.title, .summary, .composer]
    }

    static func fields(for item: CreateKitItemDraft) -> [CreateKitFocusField] {
        var fields: [CreateKitFocusField] = [
            .itemTitle(item.id),
            .itemCategory(item.id),
            .itemBrand(item.id),
            .itemModel(item.id),
            .itemNotes(item.id)
        ]

        for link in item.links {
            fields.append(.linkLabel(itemID: item.id, linkID: link.id))
            fields.append(.linkURL(itemID: item.id, linkID: link.id))
        }

        return fields
    }
}
