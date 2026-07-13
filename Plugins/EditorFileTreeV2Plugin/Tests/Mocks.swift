import Foundation
@testable import EditorFileTreeV2Plugin

// MARK: - Mock FileSystemReader

/// In-memory file system reader for testing.
/// Uses a dictionary `[URL: [URL]]` to describe directory contents.
final class MockFileSystemReader: FileSystemReading, @unchecked Sendable {
    private var directoryContents: [URL: [URL]] = [:]
    private var directoryFlags: Set<String> = []
    private var fileExistsResults: Set<String> = []

    init() {}

    func registerDirectory(_ url: URL, contents: [URL]) {
        directoryContents[url] = contents
    }

    func markAsDirectory(_ url: URL) {
        directoryFlags.insert(url.path)
    }

    func markAsFile(_ url: URL) {
        directoryFlags.remove(url.path)
    }

    func markFileExists(atPath path: String) {
        fileExistsResults.insert(path)
    }

    // MARK: - FileSystemReading

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey],
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        return directoryContents[url] ?? []
    }

    func isDirectory(_ url: URL) -> Bool {
        return directoryFlags.contains(url.path)
    }

    func fileExists(atPath path: String) -> Bool {
        return fileExistsResults.contains(path)
    }

    func sortAndFilter(_ urls: [URL]) -> [URL] {
        return urls.sorted { lhs, rhs in
            let lhsIsDir = isDirectory(lhs)
            let rhsIsDir = isDirectory(rhs)
            if lhsIsDir != rhsIsDir { return lhsIsDir }
            return lhs.lastPathComponent < rhs.lastPathComponent
        }
    }
}

// MARK: - Mock ExpandedPathStore

final class MockExpandedPathStore: ExpandedPathStoring, @unchecked Sendable {
    private var paths: [String: Set<String>] = [:]

    init() {}

    func expandedPaths(for projectRoot: String) -> Set<String> {
        return paths[projectRoot] ?? []
    }

    func addExpandedPath(_ relativePath: String, for projectRoot: String) {
        paths[projectRoot, default: []].insert(relativePath)
    }

    func removeExpandedPath(_ relativePath: String, for projectRoot: String) {
        paths[projectRoot, default: []].remove(relativePath)
    }
}

// MARK: - Test Helpers

enum TestDirHelper {
    static func createSampleProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2Test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try Data("print(1)".utf8).write(to: sources.appendingPathComponent("main.swift"))
        try Data("".utf8).write(to: root.appendingPathComponent("Package.swift"))

        return root
    }

    static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
