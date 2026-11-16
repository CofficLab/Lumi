import Testing
import Foundation
@testable import PluginDiskManager

/// Regression coverage for #850: packages (.app/.photoslibrary/…) are folded into
/// a single leaf, but their content size must be computed recursively and counted
/// in the parent directory and the scan progress instead of the directory record.
@Suite(.serialized)
struct DirectoryTreePackageSizeTests {

    @Test func topLevelSummaryCountsPackageContentRecursively() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let app = try makeAppPackage(named: "Calculator.app", in: root, executableBytes: 1000, resourceBytes: 2000)
        try Data(repeating: 3, count: 7).write(to: root.appendingPathComponent("root.bin"))

        // The fake .app must be recognised as a package, otherwise the scan would
        // descend into it and the test would not exercise the leaf-size path.
        let isPackage = (try? app.resourceValues(forKeys: [.isPackageKey]))?.isPackage ?? false
        #expect(isPackage)

        let progress = PackageProgressRecorder()
        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
            atPath: root.path,
            maxDuration: 10,
            onProgress: { value in await progress.record(value) }
        )

        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
        #expect(byName["Calculator.app"]?.size == 3000)
        #expect(byName["root.bin"]?.size == 7)

        let finalBytes = await progress.last?.scannedBytes ?? 0
        #expect(finalBytes == 3007)
    }

    @Test func fullTreeCountsPackageContentInParentDirectory() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let applications = root.appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
        try makeAppPackage(named: "Calculator.app", in: applications, executableBytes: 1000, resourceBytes: 2000)
        try Data(repeating: 3, count: 5).write(to: applications.appendingPathComponent("note.txt"))

        let entries = try await DirectoryTreeService().scanDirectoryTree(atPath: root.path)
        let parent = entry(entries, named: "Applications")
        #expect(parent?.isDirectory == true)
        #expect(parent?.size == 3005)

        let app = entry(parent?.children ?? [], named: "Calculator.app")
        #expect(app?.size == 3000)
        #expect(app?.isDirectory == false)
        #expect(app?.children == nil)
    }

    @Test func fullTreeAggregatesRegularFilesIntoParentDirectory() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let docs = root.appendingPathComponent("Docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1000).write(to: docs.appendingPathComponent("a.bin"))
        try Data(repeating: 2, count: 23).write(to: root.appendingPathComponent("top.bin"))

        let entries = try await DirectoryTreeService().scanDirectoryTree(atPath: root.path)
        #expect(entry(entries, named: "Docs")?.size == 1000)
        #expect(entry(entries, named: "top.bin")?.size == 23)
    }

    @Test func nestedPackageContentIsCountedRecursively() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let app = try makeAppPackage(named: "Outer.app", in: root, executableBytes: 1000, resourceBytes: 0)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        let inner = resources.appendingPathComponent("Inner.bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data(repeating: 5, count: 500).write(to: inner.appendingPathComponent("payload.bin"))

        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
            atPath: root.path,
            maxDuration: 10
        )
        #expect(entry(entries, named: "Outer.app")?.size == 1500)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-package-size-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    private func makeAppPackage(
        named name: String,
        in parent: URL,
        executableBytes: Int,
        resourceBytes: Int
    ) throws -> URL {
        let app = parent.appendingPathComponent(name, isDirectory: true)
        let macos = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try Data(repeating: 1, count: executableBytes).write(to: macos.appendingPathComponent("exec"))
        try Data(repeating: 2, count: resourceBytes).write(to: resources.appendingPathComponent("data.bin"))
        return app
    }

    private func entry(_ entries: [DirectoryEntry], named name: String) -> DirectoryEntry? {
        entries.first { $0.name == name }
    }
}

private actor PackageProgressRecorder {
    private(set) var values: [ScanProgress] = []

    func record(_ value: ScanProgress) {
        values.append(value)
    }

    var last: ScanProgress? { values.last }
}