import Persistence

enum MyKitsScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case drafts
    case published

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .drafts: "Drafts"
        case .published: "Published"
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: "No kits yet"
        case .drafts: "No drafts"
        case .published: "Nothing published yet"
        }
    }

    var emptyDescription: String {
        switch self {
        case .all: "Create a kit for the things you carry, pack, or use together."
        case .drafts: "New and unfinished kits will appear here."
        case .published: "Publish a finished kit to keep it in this collection."
        }
    }

    var emptySymbol: String {
        switch self {
        case .all: "duffle.bag"
        case .drafts: "pencil.and.list.clipboard"
        case .published: "checkmark.seal"
        }
    }

    func includes(_ status: LoadoutStatus) -> Bool {
        switch self {
        case .all:
            true
        case .drafts:
            status == .draft
        case .published:
            status == .published
        }
    }
}
