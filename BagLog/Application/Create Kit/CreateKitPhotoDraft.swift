import Foundation
import Persistence

struct CreateKitPhotoDraft: Identifiable, Equatable {
    let id: UUID
    let localFileName: String
    let thumbnailData: Data

    init(id: UUID, localFileName: String, thumbnailData: Data) {
        self.id = id
        self.localFileName = localFileName
        self.thumbnailData = thumbnailData
    }

    init(snapshot: LoadoutAssetSnapshot) {
        id = snapshot.id
        localFileName = snapshot.localFileName ?? ""
        thumbnailData = snapshot.thumbnailData ?? Data()
    }

    var command: LoadoutAssetCommand {
        LoadoutAssetCommand(
            id: id,
            mediaKind: .image,
            localFileName: localFileName,
            thumbnailData: thumbnailData
        )
    }
}
