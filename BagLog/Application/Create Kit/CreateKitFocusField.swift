import Foundation

enum CreateKitFocusField: Hashable {
    case profileDisplayName
    case profileHandle
    case title
    case summary
    case composer
    case itemTitle(UUID)
    case itemCategory(UUID)
    case itemBrand(UUID)
    case itemModel(UUID)
    case itemNotes(UUID)
    case linkLabel(itemID: UUID, linkID: UUID)
    case linkURL(itemID: UUID, linkID: UUID)

    var itemID: UUID? {
        switch self {
        case let .itemTitle(itemID),
             let .itemCategory(itemID),
             let .itemBrand(itemID),
             let .itemModel(itemID),
             let .itemNotes(itemID),
             let .linkLabel(itemID, _),
             let .linkURL(itemID, _):
            itemID
        case .profileDisplayName, .profileHandle, .title, .summary, .composer:
            nil
        }
    }
}
