import Foundation

public enum WorkspacePathResolver {
    public static func fileURL(from path: String) -> URL {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedPath), url.isFileURL {
            return url
        }

        let expandedPath = (trimmedPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }
}
