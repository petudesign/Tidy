import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class OrganizerModel: ObservableObject {
    @Published private(set) var folderURL: URL?
    @Published private(set) var files: [OrganizableFile] = []
    @Published private(set) var completedBatch: MoveBatch?
    @Published private(set) var isScanning = false
    @Published private(set) var isSorting = false
    @Published private(set) var isUndoing = false
    @Published var errorMessage: String?
    @Published var expandedCategories = Set<SortCategory>(SortCategory.allCases)

    var isComplete: Bool { completedBatch != nil }
    var folderName: String { folderURL?.lastPathComponent ?? "Downloads" }
    var groups: [FolderGroup] { Self.makeGroups(from: files) }
    var completedGroups: [FolderGroup] {
        guard let completedBatch else { return [] }
        let movedFiles = completedBatch.records.map {
            OrganizableFile(url: $0.destinationURL, sizeInBytes: $0.sizeInBytes, category: $0.category)
        }
        return Self.makeGroups(from: movedFiles)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder to organize"
        panel.message = "Only loose files in the folder you choose will be included."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = folderURL ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        folderURL = selectedURL
        files = []
        completedBatch = nil
        errorMessage = nil
        scanFolder()
    }

    func scanFolder() {
        guard let folderURL else { return }
        isScanning = true
        errorMessage = nil

        Task {
            do {
                let scannedFiles = try await Task.detached(priority: .userInitiated) {
                    try Self.scanFiles(in: folderURL)
                }.value
                files = scannedFiles
            } catch {
                errorMessage = "This folder could not be read. \(error.localizedDescription)"
            }
            isScanning = false
        }
    }

    func sortFiles() {
        guard let folderURL, !files.isEmpty, !isSorting else { return }
        let plannedFiles = files
        isSorting = true
        errorMessage = nil

        Task {
            do {
                let batch = try await Task.detached(priority: .userInitiated) {
                    try Self.moveFiles(plannedFiles, into: folderURL)
                }.value
                completedBatch = batch
                files = []
            } catch {
                errorMessage = "Nothing was left half-sorted. \(error.localizedDescription)"
                scanFolder()
            }
            isSorting = false
        }
    }

    func undoLastSort() {
        guard let completedBatch, !isUndoing else { return }
        isUndoing = true

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.undo(completedBatch)
            }.value

            if result.remainingRecords.isEmpty {
                self.completedBatch = nil
            } else {
                self.completedBatch = MoveBatch(
                    records: result.remainingRecords,
                    createdFolders: completedBatch.createdFolders
                )
            }
            if !result.failures.isEmpty {
                self.errorMessage = "Some files could not be moved back: \(result.failures.joined(separator: ", "))"
            }
            self.isUndoing = false
            self.scanFolder()
        }
    }

    func toggle(_ category: SortCategory) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    private static func makeGroups(from files: [OrganizableFile]) -> [FolderGroup] {
        SortCategory.allCases.compactMap { category in
            let matchingFiles = files
                .filter { $0.category == category }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return matchingFiles.isEmpty ? nil : FolderGroup(category: category, files: matchingFiles)
        }
    }

    nonisolated private static func scanFiles(in folderURL: URL) throws -> [OrganizableFile] {
        let didStartAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { folderURL.stopAccessingSecurityScopedResource() }
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]
        let contents = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory != true,
                  values.isSymbolicLink != true,
                  values.isRegularFile != false else { return nil }

            return OrganizableFile(
                url: url,
                sizeInBytes: Int64(values.fileSize ?? 0),
                category: SortCategory.classify(fileExtension: url.pathExtension)
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func moveFiles(_ files: [OrganizableFile], into rootURL: URL) throws -> MoveBatch {
        let didStartAccess = rootURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { rootURL.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        let categories = SortCategory.allCases.filter { category in files.contains { $0.category == category } }
        var createdFolders: [URL] = []
        var records: [MoveRecord] = []

        do {
            for category in categories {
                let folderURL = rootURL.appendingPathComponent(category.folderName, isDirectory: true)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) {
                    guard isDirectory.boolValue else { throw FolderSortError.nameTakenByFile(category.folderName) }
                } else {
                    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
                    createdFolders.append(folderURL)
                }
            }

            for file in files {
                let destinationFolder = rootURL.appendingPathComponent(file.category.folderName, isDirectory: true)
                let destinationURL = nonconflictingURL(for: file.url, inside: destinationFolder)
                try fileManager.moveItem(at: file.url, to: destinationURL)
                records.append(
                    MoveRecord(
                        originalURL: file.url,
                        destinationURL: destinationURL,
                        sizeInBytes: file.sizeInBytes,
                        category: file.category
                    )
                )
            }
            return MoveBatch(records: records, createdFolders: createdFolders)
        } catch {
            for record in records.reversed() where !fileManager.fileExists(atPath: record.originalURL.path) {
                try? fileManager.moveItem(at: record.destinationURL, to: record.originalURL)
            }
            removeEmptyFolders(createdFolders, using: fileManager)
            throw error
        }
    }

    nonisolated private static func undo(_ batch: MoveBatch) -> UndoResult {
        let accessURL = batch.records.first?.originalURL.deletingLastPathComponent()
        let didStartAccess = accessURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if didStartAccess { accessURL?.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        var remaining: [MoveRecord] = []
        var failures: [String] = []

        for record in batch.records.reversed() {
            if fileManager.fileExists(atPath: record.originalURL.path) {
                failures.append(record.originalURL.lastPathComponent)
                remaining.append(record)
                continue
            }
            do {
                try fileManager.moveItem(at: record.destinationURL, to: record.originalURL)
            } catch {
                failures.append(record.originalURL.lastPathComponent)
                remaining.append(record)
            }
        }

        removeEmptyFolders(batch.createdFolders, using: fileManager)
        return UndoResult(remainingRecords: remaining, failures: failures)
    }

    nonisolated private static func nonconflictingURL(for sourceURL: URL, inside folderURL: URL) -> URL {
        let fileManager = FileManager.default
        let originalCandidate = folderURL.appendingPathComponent(sourceURL.lastPathComponent)
        guard fileManager.fileExists(atPath: originalCandidate.path) else { return originalCandidate }

        let fileExtension = sourceURL.pathExtension
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        var number = 2
        while true {
            let name = fileExtension.isEmpty ? "\(stem) (\(number))" : "\(stem) (\(number)).\(fileExtension)"
            let candidate = folderURL.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            number += 1
        }
    }

    nonisolated private static func removeEmptyFolders(_ folders: [URL], using fileManager: FileManager) {
        for folderURL in folders.reversed() {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: folderURL.path), contents.isEmpty else { continue }
            try? fileManager.removeItem(at: folderURL)
        }
    }
}

private enum FolderSortError: LocalizedError {
    case nameTakenByFile(String)

    var errorDescription: String? {
        switch self {
        case .nameTakenByFile(let name):
            "A file named \(name) already exists, so its destination folder could not be created."
        }
    }
}
