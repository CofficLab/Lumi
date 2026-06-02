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

@Test func xcodePackageReferenceParserReadsUTF16ProjectFiles() throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginEditorRailFileTreeTests-\(UUID().uuidString).xcodeproj", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    try """
    // !$*UTF8*$!
    {
    \tobjects = {
    \t\tABCDEF1234567890ABCDEF12 /* XCRemoteSwiftPackageReference "swift-collections" */ = {
    \t\t\tisa = XCRemoteSwiftPackageReference;
    \t\t\trepositoryURL = "https://github.com/apple/swift-collections.git";
    \t\t\trequirement = {
    \t\t\t\tkind = upToNextMajorVersion;
    \t\t\t\tminimumVersion = 1.1.0;
    \t\t\t};
    \t\t};
    \t};
    }
    """.write(to: projectURL.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf16)

    let references = try EditorXcodePackageReferenceParser.parse(projectURL: projectURL)

    #expect(references.count == 1)
    #expect(references.first?.displayName == "swift-collections")
    #expect(references.first?.location == "https://github.com/apple/swift-collections.git")
    #expect(references.first?.requirementKind == "upToNextMajorVersion")
    #expect(references.first?.version == "1.1.0")
}
