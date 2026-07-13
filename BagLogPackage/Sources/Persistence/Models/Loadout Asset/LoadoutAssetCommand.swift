//
//  LoadoutAssetCommand.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct LoadoutAssetCommand: Sendable, Equatable {
    public let id: UUID?
    public let mediaKind: LoadoutMediaKind
    public let caption: String?
    public let localFileName: String?
    public let remoteURLString: String?
    public let thumbnailData: Data?

    public init(
        id: UUID? = nil,
        mediaKind: LoadoutMediaKind,
        caption: String? = nil,
        localFileName: String? = nil,
        remoteURLString: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.mediaKind = mediaKind
        self.caption = caption
        self.localFileName = localFileName
        self.remoteURLString = remoteURLString
        self.thumbnailData = thumbnailData
    }
}
