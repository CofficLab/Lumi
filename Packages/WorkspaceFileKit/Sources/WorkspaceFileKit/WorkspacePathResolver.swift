import Foundation

public enum WorkspacePathResolver {
    public static func fileURL(from path: String) -> URL {
        if let url = URL(string: path), url.isFileURL {
            return url
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }
}
