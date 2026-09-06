import Foundation
import ProviderProject

/// 展示当前项目打开文件的轻量投影。
public struct ProjectFilesTabState: Equatable, Sendable {
    public let fileURLs: [URL]
    public let currentFileURL: URL?

    @MainActor
    init(projectCapability: any ProjectFilesProjectCapability) {
        self.init(
            openFileURLs: projectCapability.openFileURLs,
            currentFileURL: projectCapability.currentFileURL
        )
    }

    public init(openFileURLs: [URL], currentFileURL: URL?) {
        var visibleURLs: [URL] = []
        visibleURLs.reserveCapacity(openFileURLs.count + (currentFileURL == nil ? 0 : 1))

        func appendIfNeeded(_ url: URL) {
            let standardizedURL = url.standardizedFileURL
            if !visibleURLs.contains(standardizedURL) {
                visibleURLs.append(standardizedURL)
            }
        }

        for url in openFileURLs {
            appendIfNeeded(url)
        }
        if let currentFileURL {
            appendIfNeeded(currentFileURL)
        }

        self.fileURLs = visibleURLs
        self.currentFileURL = currentFileURL?.standardizedFileURL
    }

    public var activeFileURL: URL? {
        currentFileURL
    }
}
