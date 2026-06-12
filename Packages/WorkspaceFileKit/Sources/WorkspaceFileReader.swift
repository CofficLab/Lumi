import Foundation

public enum WorkspaceFileReadResult: Equatable {
    case text(content: String, resolvedPath: String, truncated: Bool)
    case image(data: Data, mimeType: String, resolvedPath: String)
    case nonUTF8(resolvedPath: String, supportedImageExtensions: [String])
}

public struct WorkspaceFileReader: Sendable {
    public let textCharacterLimit: Int
    public let supportedImageExtensions: [String: String]

    public init(
        textCharacterLimit: Int = 50_000,
        supportedImageExtensions: [String: String] = [
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "webp": "image/webp",
        ]
    ) {
        self.textCharacterLimit = textCharacterLimit
        self.supportedImageExtensions = supportedImageExtensions
    }

    public func read(path: String) throws -> WorkspaceFileReadResult {
        let fileURL = WorkspacePathResolver.fileURL(from: path)
        let resolvedPath = fileURL.path
        let ext = fileURL.pathExtension.lowercased()
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) else {
            throw WorkspaceFileError("File does not exist: \(resolvedPath)")
        }

        guard !isDirectory.boolValue else {
            throw WorkspaceFileError("Path is a directory, not a file: \(resolvedPath)")
        }

        if let mimeType = supportedImageExtensions[ext] {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                throw WorkspaceFileError("Image file is empty: \(resolvedPath)")
            }
            return .image(data: data, mimeType: mimeType, resolvedPath: resolvedPath)
        }

        var encoding = String.Encoding.utf8
        guard let content = try? String(contentsOf: fileURL, usedEncoding: &encoding) else {
            return .nonUTF8(resolvedPath: resolvedPath, supportedImageExtensions: supportedImageExtensions.keys.sorted())
        }

        if content.count > textCharacterLimit {
            return .text(content: String(content.prefix(textCharacterLimit)), resolvedPath: resolvedPath, truncated: true)
        }

        return .text(content: content, resolvedPath: resolvedPath, truncated: false)
    }
}
