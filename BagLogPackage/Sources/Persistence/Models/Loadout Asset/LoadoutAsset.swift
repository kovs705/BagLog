//
//  LoadoutAsset.swift
//  BagLog
//
//  Created by Eugene Kovs on 12.07.2026.
//  https://github.com/kovs705
//

import Foundation
import SwiftData

@Model
public final class LoadoutAsset {
    public var id: UUID
    public var mediaKindRaw: String
    public var sortIndex: Int
    public var caption: String?
    public var localFileName: String?
    public var remoteURLString: String?

    @Attribute(.externalStorage)
    public var thumbnailData: Data?

    public var loadout: Loadout?

    public var mediaKind: LoadoutMediaKind {
        get { LoadoutMediaKind(rawValue: mediaKindRaw) ?? .image }
        set { mediaKindRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        mediaKind: LoadoutMediaKind,
        sortIndex: Int,
        caption: String? = nil,
        localFileName: String? = nil,
        remoteURLString: String? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        mediaKindRaw = mediaKind.rawValue
        self.sortIndex = sortIndex
        self.caption = caption
        self.localFileName = localFileName
        self.remoteURLString = remoteURLString
        self.thumbnailData = thumbnailData
    }
}
