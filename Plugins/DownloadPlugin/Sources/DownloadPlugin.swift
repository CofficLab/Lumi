import Foundation

/// Stateless helpers retained by the V2 download tools.
public enum DownloadPlugin {
    public nonisolated static func defaultDownloadDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    public nonisolated static func extractFilename(from url: URL) -> String {
        let pathComponent = url.lastPathComponent
        if !pathComponent.isEmpty, pathComponent != "/", !pathComponent.contains("?") {
            return pathComponent
        }
        if let query = url.query {
            for pair in query.components(separatedBy: "&") {
                let keyValue = pair.components(separatedBy: "=")
                guard keyValue.count == 2 else { continue }
                let key = keyValue[0]
                let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                if key.lowercased() == "filename" || key.lowercased() == "file" { return value }
            }
        }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "download_\(formatter.string(from: Date()))"
    }
}
