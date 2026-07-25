//
//  CKPhotoOrderTransfer.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import CoreTransferable
import Foundation

struct CreateKitPhotoOrderTransfer: Codable, Identifiable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .bagLogKitPhoto)
    }
}
