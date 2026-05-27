import Foundation

struct HTMLPreviewLoadPlanner {
    typealias FileReader = (URL) throws -> Data

    let fileReader: FileReader

    init(fileReader: @escaping FileReader = { try Data(contentsOf: $0) }) {
        self.fileReader = fileReader
    }

    func loadRequest(html: String, fileURL: URL?) -> HTMLWebViewLoadRequest {
        if let fileURL, isHTMLInSyncWithFile(html, at: fileURL) {
            return .file(
                fileURL: fileURL,
                readAccessURL: fileURL.deletingLastPathComponent()
            )
        }

        if let fileURL {
            return .html(
                html: html,
                baseURL: fileURL.deletingLastPathComponent().absoluteDirectoryURL
            )
        }

        return .html(html: html, baseURL: nil)
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
