import Foundation

public struct WorkspaceDirectoryListing: Equatable {
    public let output: String
    public let itemCount: Int
    public let truncated: Bool

    public init(output: String, itemCount: Int, truncated: Bool) {
        self.output = output
        self.itemCount = itemCount
        self.truncated = truncated
    }
}

public struct WorkspaceDirectoryLister: Sendable {
    public let maxRecursiveItems: Int

    public init(maxRecursiveItems: Int = 500) {
        self.maxRecursiveItems = maxRecursiveItems
    }

    public func list(path: String, recursive: Bool = false) throws -> WorkspaceDirectoryListing {
        let fileManager = FileManager.default
        let rootURL = WorkspacePathResolver.fileURL(from: path)
        let rootPath = rootURL.path

        guard fileManager.fileExists(atPath: rootPath) else {
            throw WorkspaceFileError("Path does not exist.")
        }

        if recursive {
            return try listRecursively(rootURL: rootURL, rootPath: rootPath)
        }

        let contents = try fileManager.contentsOfDirectory(atPath: rootPath)
        var output = ""
        var visibleCount = 0
        for item in contents {
            if item.hasPrefix(".") { continue }
            let fullPath = (rootPath as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
            output += "\(item)\(isDir.boolValue ? "/" : "")\n"
            visibleCount += 1
        }

        return WorkspaceDirectoryListing(output: output.isEmpty ? "(Empty directory)" : output, itemCount: visibleCount, truncated: false)
    }

    private func listRecursively(rootURL: URL, rootPath: String) throws -> WorkspaceDirectoryListing {
        let fileManager = FileManager.default
        var output = ""
        var stack = [rootURL]
        var count = 0
        var truncated = false

        while !stack.isEmpty {
            if count > maxRecursiveItems {
                output += "... (Too many files, stopping list)\n"
                truncated = true
                break
            }

            let currentURL = stack.removeFirst()

            if currentURL.lastPathComponent.hasPrefix(".") && currentURL != rootURL {
                continue
            }

            if currentURL != rootURL {
                let relativePath = currentURL.path.replacingOccurrences(of: rootPath, with: "")
                let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                output += "\(cleanPath)\(isDir ? "/" : "")\n"
                count += 1
            }

            let isDir = (try? currentURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                let contents = try fileManager.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                stack.append(contentsOf: contents)
            }
        }

        return WorkspaceDirectoryListing(output: output.isEmpty ? "(Empty directory)" : output, itemCount: count, truncated: truncated)
    }
}
