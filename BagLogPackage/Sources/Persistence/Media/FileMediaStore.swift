//
//  FileMeadiaStore.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum MediaStoreError: Error, Equatable, Sendable {
    case invalidFileExtension
    case invalidFileName
    case unsupportedImage
    case writeFailed
    case removeFailed
}

public struct StoredMediaFile: Sendable, Equatable {
    public let localFileName: String
    public let thumbnailData: Data

    public init(localFileName: String, thumbnailData: Data) {
        self.localFileName = localFileName
        self.thumbnailData = thumbnailData
    }
}

public protocol MediaStoring: Sendable {
    func importImage(at sourceURL: URL, for assetID: UUID) async throws -> StoredMediaFile
    func store(_ data: Data, for assetID: UUID, fileExtension: String) async throws -> String
    func remove(fileNamed fileName: String) async throws
    func contains(fileNamed fileName: String) async -> Bool
}

public actor FileMediaStore: MediaStoring {
    private let directoryURL: URL

    public init(applicationSupportDirectory: URL) throws {
        directoryURL = applicationSupportDirectory
            .appendingPathComponent("BagLog", isDirectory: true)
            .appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    public init() throws {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try self.init(applicationSupportDirectory: applicationSupportDirectory)
    }

    public func store(_ data: Data, for assetID: UUID, fileExtension: String) throws -> String {
        let normalizedExtension = try normalizedFileExtension(fileExtension)
        let fileName = "\(assetID.uuidString.lowercased()).\(normalizedExtension)"

        do {
            try data.write(to: fileURL(for: fileName), options: .atomic)
            return fileName
        } catch {
            throw MediaStoreError.writeFailed
        }
    }

    public func importImage(at sourceURL: URL, for assetID: UUID) throws -> StoredMediaFile {
        let fileExtension = try imageFileExtension(for: sourceURL)
        let fileName = "\(assetID.uuidString.lowercased()).\(fileExtension)"
        let destinationURL = fileURL(for: fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw MediaStoreError.writeFailed
        }

        do {
            let thumbnailData = try makeThumbnailData(for: destinationURL)
            return StoredMediaFile(localFileName: fileName, thumbnailData: thumbnailData)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }

    public func remove(fileNamed fileName: String) throws {
        let managedFileURL: URL

        do {
            managedFileURL = try fileURL(forManagedFileName: fileName)
        } catch {
            throw MediaStoreError.invalidFileName
        }

        guard FileManager.default.fileExists(atPath: managedFileURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: managedFileURL)
        } catch {
            throw MediaStoreError.removeFailed
        }
    }

    public func contains(fileNamed fileName: String) -> Bool {
        guard let fileURL = try? fileURL(forManagedFileName: fileName) else {
            return false
        }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}

private extension FileMediaStore {
    static let thumbnailMaximumPixelSize = 1_024

    func imageFileExtension(for sourceURL: URL) throws -> String {
        let fileExtension = sourceURL.pathExtension

        guard let contentType = UTType(filenameExtension: fileExtension),
              contentType.conforms(to: .image) else {
            throw MediaStoreError.unsupportedImage
        }

        return try normalizedFileExtension(fileExtension)
    }

    func makeThumbnailData(for imageURL: URL) throws -> Data {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw MediaStoreError.unsupportedImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaximumPixelSize
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            0,
            options as CFDictionary
        ) else {
            throw MediaStoreError.unsupportedImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaStoreError.writeFailed
        }

        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else {
            throw MediaStoreError.writeFailed
        }

        return data as Data
    }

    func normalizedFileExtension(_ fileExtension: String) throws -> String {
        let normalizedExtension = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedExtension.isEmpty,
              normalizedExtension.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw MediaStoreError.invalidFileExtension
        }
        return normalizedExtension
    }

    func fileURL(forManagedFileName fileName: String) throws -> URL {
        guard fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              !fileName.isEmpty else {
            throw MediaStoreError.invalidFileName
        }
        return fileURL(for: fileName)
    }

    func fileURL(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }
}
