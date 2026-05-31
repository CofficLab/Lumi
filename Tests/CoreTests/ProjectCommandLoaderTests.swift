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

    func testFileReferenceKeepsSentencePunctuationOutsidePath() async throws {
        let commandName = "review-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "Important release notes".write(
            to: projectURL.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try "Summarize @README.md.".write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf8
        )

        let executor = ProjectCommandExecutor()
        await executor.reloadCommands(for: projectURL.path)
        let result = await executor.executeSlashCommand("/\(commandName)")

        guard case .userMessage(let message, _) = result else {
            return XCTFail("Expected userMessage, got \(result)")
        }

        XCTAssertTrue(message.contains("// File: README.md"))
        XCTAssertTrue(message.contains("Important release notes"))
        XCTAssertTrue(message.hasSuffix("```."))
        XCTAssertFalse(message.contains("[文件不存在]"))
    }

    func testFileReferenceDoesNotRewriteEmailAddresses() async throws {
        let commandName = "email-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "Release context".write(
            to: projectURL.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        try "Email support@example.com and summarize @README.md".write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf8
        )

        let executor = ProjectCommandExecutor()
        await executor.reloadCommands(for: projectURL.path)
        let result = await executor.executeSlashCommand("/\(commandName)")

        guard case .userMessage(let message, _) = result else {
            return XCTFail("Expected userMessage, got \(result)")
        }

        XCTAssertTrue(message.contains("support@example.com"))
        XCTAssertTrue(message.contains("// File: README.md"))
        XCTAssertTrue(message.contains("Release context"))
        XCTAssertFalse(message.contains("@example.com [文件不存在]"))
    }
}
#endif
