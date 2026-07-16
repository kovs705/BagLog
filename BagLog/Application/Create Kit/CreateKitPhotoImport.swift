import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct CreateKitPhotoImport: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { receivedFile in
            let fileExtension = receivedFile.file.pathExtension
            let temporaryURL = URL.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appendingPathExtension(fileExtension)

            try FileManager.default.copyItem(at: receivedFile.file, to: temporaryURL)
            return CreateKitPhotoImport(fileURL: temporaryURL)
        }
    }
}
