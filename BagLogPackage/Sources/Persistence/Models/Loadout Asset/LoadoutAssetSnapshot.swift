//
//  LoadoutAssetSnapshot.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct LoadoutAssetSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let mediaKind: LoadoutMediaKind
    public let sortIndex: Int
    public let caption: String?
    public let localFileName: String?
    public let remoteURLString: String?
    public let thumbnailData: Data?

    public init(
        id: UUID,
        mediaKind: LoadoutMediaKind,
        sortIndex: Int,
        caption: String?,
        localFileName: String?,
        remoteURLString: String?,
        thumbnailData: Data?
    ) {
        self.id = id
        self.mediaKind = mediaKind
        self.sortIndex = sortIndex
        self.caption = caption
        self.localFileName = localFileName
        self.remoteURLString = remoteURLString
        self.thumbnailData = thumbnailData
    }
}
