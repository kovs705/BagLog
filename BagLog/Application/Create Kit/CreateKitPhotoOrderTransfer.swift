import CoreTransferable
import Foundation

struct CreateKitPhotoOrderTransfer: Codable, Identifiable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .bagLogKitPhoto)
    }
}
