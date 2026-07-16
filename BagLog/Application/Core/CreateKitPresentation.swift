import Foundation

enum CreateKitPresentation: Identifiable, Equatable {
    case new
    case edit(UUID)

    var id: String {
        switch self {
        case .new: "new-kit"
        case let .edit(loadoutID): "edit-\(loadoutID.uuidString)"
        }
    }
}
