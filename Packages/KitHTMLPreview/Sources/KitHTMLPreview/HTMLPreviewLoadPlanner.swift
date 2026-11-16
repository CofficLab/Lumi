import Foundation

struct HTMLPreviewLoadPlanner {
    typealias FileReader = (URL) throws -> Data

    let fileReader: FileReader

    init(fileReader: @escaping FileReader = { try Data(contentsOf: $0) }) {
        self.fileReader = fileReader
    }

    func loadRequest(html: String, fileURL: URL?, readAccessRootURL: URL? = nil) -> HTMLWebViewLoadRequest {
        guard let fileURL else {
            return .html(html: html, baseURL: nil)
        }

        // 调用方只提供文件（如快照失败后的 Canvas 回退）时，文件就是唯一内容源。
        if html.isEmpty, let data = try? fileReader(fileURL), !data.isEmpty {
            return .file(
                fileURL: fileURL,
                readAccessURL: readAccessRoot(for: fileURL, preferred: readAccessRootURL)
            )
        }

        if isHTMLInSyncWithFile(html, at: fileURL) {
            return .file(
                fileURL: fileURL,
                readAccessURL: readAccessRoot(for: fileURL, preferred: readAccessRootURL)
            )
        }

        return .html(
            html: html,
            baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
        )
    }

    /// 仅在加载键变化（`didReload == true`）时才规划加载。
    ///
    /// 加载键未变化时调用方本来就不会触发新加载，此时整文件磁盘读取与字符串比较
    /// 纯属浪费——而 `updateNSView` 会在每次 SwiftUI 更新（含每帧 resize）触发。
    /// 这里直接返回 nil，跳过 I/O（见 issue #1280）。
    func loadRequestIfNeeded(
        didReload: Bool,
        html: String,
        fileURL: URL?,
        readAccessRootURL: URL? = nil
    ) -> HTMLWebViewLoadRequest? {
        guard didReload else { return nil }
        return loadRequest(html: html, fileURL: fileURL, readAccessRootURL: readAccessRootURL)
    }

    /// 子目录中的页面（如本地化 HTML）需要读取上级目录的共享资源；
    /// 仅当首选目录确实包含该文件时才采用，避免把读取权限放大到无关目录。
    private func readAccessRoot(for fileURL: URL, preferred: URL?) -> URL {
        let parent = fileURL.deletingLastPathComponent()
        guard let preferred else { return parent }
        let filePath = fileURL.standardizedFileURL.path
        let preferredPath = preferred.standardizedFileURL.path
        guard filePath.hasPrefix(preferredPath + "/") else { return parent }
        return preferred
    }

    func isHTMLInSyncWithFile(_ html: String, at url: URL) -> Bool {
        guard let data = try? fileReader(url),
              let fileText = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            return false
        }
        return fileText == html
    }
}

enum HTMLWebViewLoadRequest: Equatable {
    case file(fileURL: URL, readAccessURL: URL)
    case html(html: String, baseURL: URL?)
}

extension URL {
    var absoluteDirectoryURL: URL {
        var absoluteString = absoluteString
        if !absoluteString.hasSuffix("/") {
            absoluteString += "/"
        }
        return URL(string: absoluteString) ?? self
    }
}
