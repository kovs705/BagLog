//
//  FileMeadiaStore.swift
//  BagLog
//
//  Created by Eugene Kovs on 10.07.2026.
//  https://github.com/kovs705
//

import Foundation

public enum MediaStoreError: Error, Equatable, Sendable {
    case invalidFileExtension
    case invalidFileName
    case writeFailed
    case removeFailed
}

public protocol MediaStoring: Sendable {
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
