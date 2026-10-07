import SwiftUI

enum TidyStyle {
    static let ink = Color(hex: 0x20221F)
    static let muted = Color(hex: 0x74766F)
    static let line = Color(hex: 0xE6E4DE)
    static let paper = Color(hex: 0xFFFEFA)
    static let paperSoft = Color(hex: 0xFAF9F5)
    static let canvas = Color(hex: 0xF4F2ED)
    static let green = Color(hex: 0x5D8152)
    static let greenDark = Color(hex: 0x4F7146)
    static let greenWash = Color(hex: 0xEDF4E9)
    static let folderBlue = Color(hex: 0x4B96D3)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum SortCategory: String, CaseIterable, Identifiable, Hashable {
    case images
    case installers
    case documents
    case archives
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .images: "Images"
        case .installers: "Installers"
        case .documents: "Documents"
        case .archives: "Archives"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .images: "photo.on.rectangle.angled"
        case .installers: "arrow.down.app"
        case .documents: "doc.text"
        case .archives: "archivebox"
        case .other: "folder"
        }
    }

    var folderName: String { title }

    static func classify(fileExtension: String) -> SortCategory {
        let ext = fileExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "svg", "avif", "raw", "cr2", "nef", "arw"].contains(ext) {
            return .images
        }
        if ["dmg", "pkg", "mpkg", "exe", "msi"].contains(ext) {
            return .installers
        }
        if ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar"].contains(ext) {
            return .archives
        }
        if ["pdf", "doc", "docx", "odt", "pages", "txt", "rtf", "md", "csv", "xls", "xlsx", "numbers", "ppt", "pptx", "key", "epub"].contains(ext) {
            return .documents
        }
        return .other
    }
}

struct OrganizableFile: Identifiable, Hashable, Sendable {
    let url: URL
    let sizeInBytes: Int64
    let category: SortCategory

    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var formattedSize: String { Self.formatBytes(sizeInBytes) }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }
}

struct FolderGroup: Identifiable, Sendable {
    let category: SortCategory
    let files: [OrganizableFile]

    var id: SortCategory { category }
    var totalSize: Int64 { files.reduce(0) { $0 + $1.sizeInBytes } }
    var formattedSize: String { OrganizableFile.formatBytes(totalSize) }
}

struct MoveRecord: Sendable {
    let originalURL: URL
    let destinationURL: URL
    let sizeInBytes: Int64
    let category: SortCategory
}

struct MoveBatch: Sendable {
    let records: [MoveRecord]
    let createdFolders: [URL]
}

struct UndoResult: Sendable {
    let remainingRecords: [MoveRecord]
    let failures: [String]
}
