import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileThumbnail: View {
    let url: URL
    let category: SortCategory

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFill()
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable().scaledToFit().padding(2).background(tint.opacity(0.12))
            }
        }
        .frame(width: 25, height: 25)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.7)
        }
        .task(id: url) { await loadThumbnail() }
    }

    private var tint: Color {
        switch category {
        case .images: Color(hex: 0x6C8B56)
        case .installers: Color(hex: 0x77818A)
        case .documents: Color(hex: 0x4C79AE)
        case .archives: Color(hex: 0xAA7937)
        case .other: Color(hex: 0x82837C)
        }
    }

    @MainActor
    private func loadThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 64, height: 64),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )
        let image = await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
        thumbnail = image
    }
}
