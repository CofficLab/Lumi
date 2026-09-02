import AppKit
import SwiftUI

struct CachedScreenshotThumbnail<Placeholder: View, Failure: View>: View {
    let url: URL
    let screenshotID: String
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didFail {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            image = nil
            didFail = false
            do {
                let data = try await ScreenshotImageCache.shared.data(for: url, screenshotID: screenshotID)
                guard !Task.isCancelled else { return }
                guard let loaded = NSImage(data: data) else {
                    didFail = true
                    return
                }
                image = loaded
            } catch {
                guard !Task.isCancelled else { return }
                didFail = true
            }
        }
    }
}
