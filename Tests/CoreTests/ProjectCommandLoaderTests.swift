#if canImport(XCTest)
import XCTest
@testable import Lumi

final class ProjectCommandLoaderTests: XCTestCase {
    func testRelativePathOnlyDropsCommandDirectoryPrefix() {
        let directory = URL(fileURLWithPath: "/tmp/project/.agent/commands")
        let fileURL = URL(fileURLWithPath: "/tmp/project/.agent/commands/nested/tmp/project/.agent/commands/deploy.md")

        XCTAssertEqual(
            ProjectCommandLoader.relativePath(for: fileURL, in: directory),
            "nested/tmp/project/.agent/commands/deploy.md"
        )
    }

    func testRelativePathRejectsSiblingWithSharedPrefix() {
        let directory = URL(fileURLWithPath: "/tmp/project/.agent/commands")
        let fileURL = URL(fileURLWithPath: "/tmp/project/.agent/commands-copy/deploy.md")

        XCTAssertEqual(ProjectCommandLoader.relativePath(for: fileURL, in: directory), "deploy.md")
    }

    func testCommandNameOnlyDropsFinalMarkdownExtension() {
        let directory = URL(fileURLWithPath: "/tmp/project/.agent/commands")
        let fileURL = URL(fileURLWithPath: "/tmp/project/.agent/commands/release.md.notes.md")

        XCTAssertEqual(ProjectCommandLoader.commandName(for: fileURL, in: directory), "release.md.notes")
    }
}
#endif
