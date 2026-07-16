import CoreTransferable
import Foundation

struct CreateKitItemTransfer: Codable, Identifiable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .bagLogKitItem)
    }
}
