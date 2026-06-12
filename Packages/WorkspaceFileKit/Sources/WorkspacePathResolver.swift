import Foundation

public enum WorkspacePathResolver {
    public static func fileURL(from path: String) -> URL {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedPath), url.isFileURL {
            return url
        }
        if trimmedPath.lowercased().hasPrefix("file://") {
            let rawPath = String(trimmedPath.dropFirst("file://".count))
            let path = rawPath
                .replacingOccurrences(of: "^localhost", with: "", options: .regularExpression)
                .removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
        }

        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }
}
