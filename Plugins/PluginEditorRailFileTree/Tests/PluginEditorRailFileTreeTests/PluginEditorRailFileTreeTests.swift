import Testing
import Foundation
@testable import PluginEditorRailFileTree

@Test func expansionPathOnlyDropsRootPrefix() {
    let rootPath = "/tmp/project"
    let nodeURL = URL(fileURLWithPath: "/tmp/project/nested/tmp/project/file.swift")

    #expect(EditorFileTreePathFormatter.expansionPath(for: nodeURL, projectRootPath: rootPath) == "/nested/tmp/project/file.swift")
}

@Test func expansionPathRejectsSiblingWithSharedPrefix() {
    let rootPath = "/tmp/project"
    let sibling = URL(fileURLWithPath: "/tmp/project-copy/file.swift")

    #expect(EditorFileTreePathFormatter.expansionPath(for: sibling, projectRootPath: rootPath) == "/tmp/project-copy/file.swift")
}

@Test func gitPathDoesNotIncludeLeadingSlash() {
    let rootPath = "/tmp/project"
    let nodeURL = URL(fileURLWithPath: "/tmp/project/Sources/App.swift")

    #expect(EditorFileTreePathFormatter.gitPath(for: nodeURL, projectRootPath: rootPath) == "Sources/App.swift")
}
