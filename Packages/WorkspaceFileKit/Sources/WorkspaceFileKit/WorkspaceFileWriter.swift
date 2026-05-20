import Foundation

public struct WorkspaceFileWriter: Sendable {
    public init() {}

    public func write(path: String, content: String) throws {
        let fileURL = WorkspacePathResolver.fileURL(from: path)
        let directoryURL = fileURL.deletingLastPathComponent()

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
