import Foundation

public struct WorkspaceFileWriter: Sendable {
    public init() {}

    public func write(path: String, content: String) throws {
        let fileURL = WorkspacePathResolver.fileURL(from: path)
        let directoryURL = fileURL.deletingLastPathComponent()

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                throw WorkspaceFileError("Path is a directory, not a file: \(fileURL.path)")
            }
        }

        isDirectory = false
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw WorkspaceFileError("Parent path is not a directory: \(directoryURL.path)")
            }
        } else {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
