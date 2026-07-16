struct CreateKitFocusOrder {
    static func fields(for draft: CreateKitDraft?) -> [CreateKitFocusField] {
        guard let draft else {
            return [.profileDisplayName, .profileHandle]
        }

        var fields: [CreateKitFocusField] = [.title, .summary, .composer]

        for item in draft.items {
            fields.append(contentsOf: [
                .itemTitle(item.id),
                .itemCategory(item.id),
                .itemBrand(item.id),
                .itemModel(item.id),
                .itemNotes(item.id)
            ])

            for link in item.links {
                fields.append(.linkLabel(itemID: item.id, linkID: link.id))
                fields.append(.linkURL(itemID: item.id, linkID: link.id))
            }
        }

        return fields
    }
}
