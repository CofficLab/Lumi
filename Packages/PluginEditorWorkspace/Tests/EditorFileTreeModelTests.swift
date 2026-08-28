import Foundation
import PluginEditorWorkspace
import Testing

@MainActor
struct EditorFileTreeModelTests {
    @Test("sorts folders first and excludes generated directories")
    func sortsAndFilters() async throws {
        let fixture = try FileTreeFixture()
        try fixture.directory("Sources")
        try fixture.directory("node_modules")
        try fixture.directory(".git")
        try fixture.file("z.swift")
        try fixture.file("a.md")
        let model = EditorFileTreeModel()

        await model.setRoot(fixture.root)

        let names = try #require(model.root?.children).map(\.name)
        #expect(names == ["Sources", "a.md", "z.swift"])
    }

    @Test("loads nested folders lazily")
    func lazyExpansion() async throws {
        let fixture = try FileTreeFixture()
        try fixture.file("Sources/App.swift")
        let model = EditorFileTreeModel()
        await model.setRoot(fixture.root)
        let sources = try #require(model.root?.children?.first)

        #expect(sources.children == nil)
        await model.expand(sources)
        #expect(sources.children?.map(\.name) == ["App.swift"])
    }

    @Test("refresh preserves expanded folders")
    func refreshPreservesExpansion() async throws {
        let fixture = try FileTreeFixture()
        try fixture.file("Sources/App.swift")
        let model = EditorFileTreeModel()
        await model.setRoot(fixture.root)
        let sources = try #require(model.root?.children?.first)
        await model.expand(sources)
        try fixture.file("Sources/New.swift")

        await model.refresh()

        let refreshed = try #require(model.root?.children?.first)
        #expect(refreshed.isExpanded)
        #expect(refreshed.children?.map(\.name) == ["App.swift", "New.swift"])
    }
}

private struct FileTreeFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorFileTreeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func directory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func file(_ relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "fixture".write(to: url, atomically: true, encoding: .utf8)
    }
}
