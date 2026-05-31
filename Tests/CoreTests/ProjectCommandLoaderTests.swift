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

    func testFrontmatterParsesCRLFFiles() {
        let content = """
        ---\r
        description: Run release checks\r
        allowed-tools: Read, Bash\r
        model: gpt-5\r
        argument-hint: version\r
        disable-model-invocation: true\r
        ---\r
        Ship $ARGUMENTS\r
        """

        let result = CommandFrontmatter.parse(from: content)

        XCTAssertEqual(result.frontmatter?.description, "Run release checks")
        XCTAssertEqual(result.frontmatter?.allowedTools, ["Read", "Bash"])
        XCTAssertEqual(result.frontmatter?.model, "gpt-5")
        XCTAssertEqual(result.frontmatter?.argumentHint, "version")
        XCTAssertEqual(result.frontmatter?.disableModelInvocation, true)
        XCTAssertEqual(result.body, "Ship $ARGUMENTS\n")
    }
}
#endif
