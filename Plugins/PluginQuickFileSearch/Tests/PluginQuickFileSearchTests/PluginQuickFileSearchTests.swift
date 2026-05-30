import Testing
import Foundation
@testable import PluginQuickFileSearch

@Test func scanProjectFilesOnlyDropsRootPrefix() throws {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuickFileSearchTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let nestedDirectory = rootURL
        .appendingPathComponent("nested", isDirectory: true)
        .appendingPathComponent(rootURL.path, isDirectory: true)
    try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
    try "content".write(to: nestedDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

    let results = FileSearchHelpers.scanProjectFiles(at: rootURL.path)
    let file = try #require(results.first { $0.name == "file.txt" })

    #expect(file.relativePath == "nested/\(String(rootURL.path.dropFirst()))/file.txt")
}

@Test func relativePathRejectsSiblingWithSharedPrefix() {
    let rootPath = "/tmp/project"
    let sibling = URL(fileURLWithPath: "/tmp/project-copy/file.txt")

    #expect(FileSearchHelpers.relativePath(for: sibling, rootPath: rootPath) == "file.txt")
}
