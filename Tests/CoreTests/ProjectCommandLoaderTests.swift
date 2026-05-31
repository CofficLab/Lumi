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

    func testLoaderReadsUTF16CommandFiles() async throws {
        let commandName = "utf16-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try """
        ---
        description: UTF16 command
        ---
        Summarize $ARGUMENTS
        """.write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf16
        )

        let loader = ProjectCommandLoader()
        let commands = await loader.loadCommands(for: projectURL.path)
        let command = try XCTUnwrap(commands.first)

        XCTAssertEqual(command.name, commandName)
        XCTAssertEqual(command.description, "UTF16 command")
        XCTAssertEqual(command.content, "Summarize $ARGUMENTS")
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

    func testFileReferenceReadsUTF16Files() async throws {
        let commandName = "reference-utf16-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "Important UTF16 notes".write(
            to: projectURL.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf16
        )
        try "Summarize @README.md".write(
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
        XCTAssertTrue(message.contains("Important UTF16 notes"))
        XCTAssertFalse(message.contains("[文件不存在]"))
    }

    func testQuotedFileReferenceReadsPathsWithSpaces() async throws {
        let commandName = "quoted-reference-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "Release notes with spaces".write(
            to: projectURL.appendingPathComponent("Release Notes.md"),
            atomically: true,
            encoding: .utf8
        )
        try "Summarize @\"Release Notes.md\".".write(
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

        XCTAssertTrue(message.contains("// File: Release Notes.md"))
        XCTAssertTrue(message.contains("Release notes with spaces"))
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

    func testPositionalArgumentsRespectQuotedValues() async throws {
        let commandName = "args-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "First=$1\nSecond=$2\nAll=$ARGUMENTS".write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf8
        )

        let executor = ProjectCommandExecutor()
        await executor.reloadCommands(for: projectURL.path)
        let result = await executor.executeSlashCommand("/\(commandName) \"release notes\" beta")

        guard case .userMessage(let message, _) = result else {
            return XCTFail("Expected userMessage, got \(result)")
        }

        XCTAssertTrue(message.contains("First=release notes"))
        XCTAssertTrue(message.contains("Second=beta"))
        XCTAssertTrue(message.contains("All=\"release notes\" beta"))
    }

    func testPositionalArgumentReplacementKeepsDoubleDigitPlaceholdersDistinct() async throws {
        let commandName = "args10-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "First=$1\nTenth=$10".write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf8
        )

        let executor = ProjectCommandExecutor()
        await executor.reloadCommands(for: projectURL.path)
        let result = await executor.executeSlashCommand("/\(commandName) one two three four five six seven eight nine ten")

        guard case .userMessage(let message, _) = result else {
            return XCTFail("Expected userMessage, got \(result)")
        }

        XCTAssertTrue(message.contains("First=one"))
        XCTAssertTrue(message.contains("Tenth=ten"))
        XCTAssertFalse(message.contains("Tenth=one0"))
    }

    func testEscapedPositionalArgumentStaysLiteral() async throws {
        let commandName = "literal-args-\(UUID().uuidString)"
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectCommandLoaderTests-\(UUID().uuidString)")
        let commandsURL = projectURL
            .appendingPathComponent(".agent")
            .appendingPathComponent("commands")

        try FileManager.default.createDirectory(at: commandsURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try "Literal=\\$1\nActual=$1".write(
            to: commandsURL.appendingPathComponent("\(commandName).md"),
            atomically: true,
            encoding: .utf8
        )

        let executor = ProjectCommandExecutor()
        await executor.reloadCommands(for: projectURL.path)
        let result = await executor.executeSlashCommand("/\(commandName) release")

        guard case .userMessage(let message, _) = result else {
            return XCTFail("Expected userMessage, got \(result)")
        }

        XCTAssertTrue(message.contains("Literal=$1"))
        XCTAssertTrue(message.contains("Actual=release"))
        XCTAssertFalse(message.contains("Literal=\\$1"))
    }
}
#endif
