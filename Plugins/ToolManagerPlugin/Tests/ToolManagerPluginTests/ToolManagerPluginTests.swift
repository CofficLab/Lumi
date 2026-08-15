import Foundation
import KernelLumi
import Testing
@testable import ToolManagerPlugin

@Suite("ToolManagerPlugin", .serialized)
@MainActor
struct ToolManagerPluginTests {
    // MARK: - ReadFileLineReader

    @Test("reads selected lines with stable line numbers")
    func readSelectedLines() {
        let result = ReadFileLineReader.read(
            content: "one\ntwo\nthree\nfour",
            request: .init(offset: 2, limit: 2)
        )

        #expect(result.startLine == 2)
        #expect(result.endLine == 3)
        #expect(result.totalLines == 4)
        #expect(result.formattedContent == "2|two\n3|three\n\n[Showing lines 2-3 of 4. Use offset=4 with limit to read more.]")
    }

    @Test("supports negative offsets and clamps limits")
    func negativeOffsetAndLimit() {
        let result = ReadFileLineReader.read(
            content: "one\ntwo\nthree\nfour",
            request: .init(offset: -2, limit: 9999)
        )

        #expect(result.startLine == 3)
        #expect(result.endLine == 4)
        #expect(result.formattedContent.contains("3|three"))
        #expect(result.formattedContent.contains("4|four"))
    }

    @Test("handles empty and CRLF files")
    func emptyAndCRLF() {
        #expect(ReadFileLineReader.read(content: "", request: .init(offset: nil, limit: nil)).totalLines == 0)

        let result = ReadFileLineReader.read(
            content: "one\r\ntwo\r\n",
            request: .init(offset: nil, limit: nil)
        )
        #expect(result.totalLines == 2)
        #expect(result.formattedContent.contains("1|one"))
        #expect(result.formattedContent.contains("2|two"))
    }

    @Test("streams large files without loading the complete contents")
    func streamsLargeFile() async throws {
        let fileURL = try temporaryFile(named: "large.txt", contents: makeLines(count: 12_000, width: 1_024))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let result = try await ReadFileLineReader.read(
            fileURL: fileURL,
            request: .init(offset: 9_000, limit: 3),
            maxWholeFileBytes: 10 * 1024 * 1024
        )

        #expect(result.startLine == 9_000)
        #expect(result.endLine == 9_002)
        #expect(result.totalLines == 12_000)
        #expect(result.formattedContent.utf8.count <= ReadFileLineReader.maxOutputBytes + 100)
    }

    @Test("rejects a large file without an explicit offset")
    func rejectsLargeWholeFileRead() async throws {
        let fileURL = try temporaryFile(named: "too-large.txt", contents: Data(repeating: 0x61, count: 11 * 1024 * 1024))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await #expect(throws: ReadFileLineReader.ReadError.self) {
            _ = try await ReadFileLineReader.read(
                fileURL: fileURL,
                request: .init(offset: nil, limit: nil),
                maxWholeFileBytes: 10 * 1024 * 1024
            )
        }
    }

    @Test("rejects binary content")
    func rejectsBinaryContent() async throws {
        let fileURL = try temporaryFile(named: "binary.dat", contents: Data([0x61, 0x00, 0x62]))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await #expect(throws: ReadFileLineReader.ReadError.self) {
            _ = try await ReadFileLineReader.read(
                fileURL: fileURL,
                request: .init(offset: 1, limit: 1),
                maxWholeFileBytes: 10 * 1024 * 1024
            )
        }
    }

    @Test("truncates an unusually long line")
    func truncatesLongLine() async throws {
        let fileURL = try temporaryFile(
            named: "long-line.txt",
            contents: Data(repeating: 0x78, count: ReadFileLineReader.maxLineBytes + 10)
        )
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let result = try await ReadFileLineReader.read(
            fileURL: fileURL,
            request: .init(offset: 1, limit: 1),
            maxWholeFileBytes: 10 * 1024 * 1024
        )
        #expect(result.formattedContent.contains("[line truncated]"))
        #expect(result.formattedContent.utf8.count < ReadFileLineReader.maxLineBytes + 100)
    }

    // MARK: - File tools

    @Test("read file tool reads text and enforces path access")
    func readFileTool() async throws {
        let fileURL = try temporaryFile(named: "read.txt", contents: Data("alpha\nbeta\n".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let tool = ReadFileTool()
        let kernel = KernelLumi()
        let result = try await tool.execute(
            arguments: ["path": .string(fileURL.path), "offset": .int(2), "limit": .int(1)],
            kernel: kernel
        )
        #expect(result.contains("2|beta"))

        let blocked = KernelLumi()
        let context = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "call",
            toolName: tool.name,
            allowedDirectories: [fileURL.deletingLastPathComponent().appendingPathComponent("other").path]
        )
        await #expect(throws: Error.self) {
            try await blocked.withToolExecutionContextState(context) {
                try await tool.execute(arguments: ["path": .string(fileURL.path)], kernel: blocked)
            }
        }
    }

    @Test("read file tool covers descriptions and image size guard")
    func readFileToolMetadataAndImageGuard() async throws {
        let tool = ReadFileTool()
        #expect(tool.displayDescription(arguments: [:]) == "读取文件")
        #expect(tool.displayDescription(arguments: ["path": .string("/tmp/example.txt")]) == "读取 example.txt")
        #expect(tool.displayDescription(arguments: ["path": .string("/tmp/example.txt"), "offset": .int(2)]) == "读取 example.txt（从第 2 行起）")
        #expect(tool.displayDescription(arguments: ["path": .string("/tmp/example.txt"), "offset": .int(2), "limit": .int(3)]) == "读取 example.txt（第 2 行起，最多 3 行）")
        #expect(tool.riskLevel(arguments: [:], kernel: KernelLumi()) == .low)

        let imageURL = try temporaryFile(
            named: "large.png",
            contents: Data(repeating: 0x01, count: 10 * 1024 * 1024 + 1)
        )
        defer { try? FileManager.default.removeItem(at: imageURL) }
        let result = try await tool.execute(arguments: ["path": .string(imageURL.path)], kernel: KernelLumi())
        #expect(result.contains("too large") || result.contains("太大"))

        let validImageURL = try temporaryFile(
            named: "pixel.png",
            contents: Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        )
        defer { try? FileManager.default.removeItem(at: validImageURL) }
        let imageKernel = KernelLumi()
        let imageResult = try await tool.execute(arguments: ["path": .string(validImageURL.path)], kernel: imageKernel)
        #expect(imageResult.contains("已加载图片"))
    }

    @Test("file tools reject missing and disallowed arguments")
    func fileToolArgumentErrors() async throws {
        let kernel = KernelLumi()
        await #expect(throws: Error.self) { try await ReadFileTool().execute(arguments: [:], kernel: kernel) }
        await #expect(throws: Error.self) { try await WriteFileTool().execute(arguments: [:], kernel: kernel) }
        await #expect(throws: Error.self) { try await EditFileTool().execute(arguments: [:], kernel: kernel) }

        let denied = KernelLumi()
        let context = LumiToolExecutionContextState(
            conversationID: UUID(), toolCallID: "denied", toolName: "write_file",
            allowedDirectories: ["/definitely/not/allowed"]
        )
        await #expect(throws: Error.self) {
            try await denied.withToolExecutionContextState(context) {
                try await WriteFileTool().execute(
                    arguments: ["path": .string("/tmp/denied.txt"), "content": .string("x")], kernel: denied
                )
            }
        }
    }

    @Test("write and edit tools modify files")
    func writeAndEditTools() async throws {
        let fileURL = temporaryURL(named: "nested/write.txt")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent().deletingLastPathComponent()) }
        let kernel = KernelLumi()

        let writeResult = try await WriteFileTool().execute(
            arguments: ["path": .string(fileURL.path), "content": .string("hello hello")],
            kernel: kernel
        )
        #expect(writeResult.contains("Wrote 11 characters"))

        let editResult = try await EditFileTool().execute(
            arguments: [
                "file_path": .string(fileURL.path),
                "old_string": .string("hello"),
                "new_string": .string("hi"),
                "replace_all": .bool(true),
            ],
            kernel: kernel
        )
        #expect(editResult.contains("All 2 occurrences"))
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "hi hi")

        let newURL = fileURL.deletingLastPathComponent().appendingPathComponent("new.txt")
        let created = try await EditFileTool().execute(
            arguments: ["file_path": .string(newURL.path), "old_string": .string(""), "new_string": .string("created")],
            kernel: kernel
        )
        #expect(created.contains("Created new file"))

        let emptyURL = fileURL.deletingLastPathComponent().appendingPathComponent("empty.txt")
        FileManager.default.createFile(atPath: emptyURL.path, contents: Data())
        let filled = try await EditFileTool().execute(
            arguments: ["file_path": .string(emptyURL.path), "old_string": .string(""), "new_string": .string("filled")],
            kernel: kernel
        )
        #expect(filled.contains("Wrote content to empty file"))
    }

    @Test("list directory sorts and truncates entries")
    func listDirectory() async throws {
        let directoryURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try Data("a".utf8).write(to: directoryURL.appendingPathComponent("b.txt"))
        try Data("a".utf8).write(to: directoryURL.appendingPathComponent("a.txt"))
        try FileManager.default.createDirectory(at: directoryURL.appendingPathComponent("folder"), withIntermediateDirectories: false)

        let result = try await ListDirectoryTool().execute(
            arguments: ["path": .string(directoryURL.path)],
            kernel: KernelLumi()
        )
        #expect(result.split(separator: "\n").first == "a.txt")
        #expect(result.contains("folder/"))

        let recursive = try await ListDirectoryTool().execute(
            arguments: ["path": .string(directoryURL.path), "recursive": .bool(true)], kernel: KernelLumi()
        )
        #expect(recursive.contains("folder/"))

        let missing = try await ListDirectoryTool().execute(
            arguments: ["path": .string(directoryURL.appendingPathComponent("missing").path)], kernel: KernelLumi()
        )
        #expect(missing.contains("Directory does not exist"))
    }

    @Test("glob finds files under the current search root")
    func globTool() async throws {
        let directoryURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let nested = directoryURL.appendingPathComponent("Sources/Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("swift".utf8).write(to: nested.appendingPathComponent("Feature.swift"))
        try Data("text".utf8).write(to: nested.appendingPathComponent("Feature.txt"))

        let result = try await GlobTool().execute(
            arguments: ["path": .string(directoryURL.path), "pattern": .string("**/*.swift")],
            kernel: KernelLumi()
        )
        #expect(result.contains("Sources/Nested/Feature.swift"))
        #expect(!result.contains("Feature.txt"))
    }

    @Test("shell tool returns command output and validates arguments")
    func shellTool() async throws {
        let tool = ShellTool()
        let kernel = KernelLumi()
        let result = try await tool.execute(
            arguments: ["command": .string("printf 'hello'")],
            kernel: kernel
        )
        #expect(result == "hello")

        await #expect(throws: Error.self) {
            _ = try await tool.execute(arguments: [:], kernel: kernel)
        }
        #expect(tool.riskLevel(arguments: [:], kernel: kernel) == .high)
        #expect(tool.riskLevel(arguments: ["command": .string(" sudo rm file")], kernel: kernel) == .high)
        #expect(tool.riskLevel(arguments: ["command": .string("printf ok")], kernel: kernel) == .low)
        #expect(tool.displayDescription(arguments: [:]) == "运行命令")
        #expect(tool.displayDescription(arguments: ["command": .string(String(repeating: "x", count: 50))]).hasSuffix("…"))

        let failed = try await tool.execute(arguments: ["command": .string("printf error >&2; exit 3")], kernel: kernel)
        #expect(failed.contains("Exit code: 3"))
    }

    // MARK: - ToolManagerService

    @Test("service preserves registration order and plugin grouping")
    func serviceRegistration() {
        let service = ToolManagerService()
        let first = TestTool(name: "first")
        let second = TestTool(name: "second")
        service.add(first, pluginID: "plugin.a")
        service.add(second, pluginID: "plugin.b")

        #expect(service.allAgentTools().map(\.name) == ["first", "second"])
        #expect(service.agentToolsGroupedByPlugin().map(\.pluginID) == ["plugin.a", "plugin.b"])

        service.add(first, pluginID: "plugin.b")
        #expect(service.agentToolsGroupedByPlugin().map(\.pluginID) == ["plugin.b"])

        service.remove(id: "first")
        #expect(service.allAgentTools().map(\.name) == ["second"])
    }

    @Test("service handles unknown, invalid and successful calls")
    func serviceExecution() async {
        let service = ToolManagerService()
        let tool = TestTool(name: "echo")
        service.add(tool, pluginID: "tests")
        let conversationID = UUID()

        let unknown = await service.execute(
            LumiToolCall(id: "unknown", name: "missing", arguments: "{}"),
            conversationID: conversationID
        )
        #expect(unknown.isError)
        #expect(unknown.content.contains("Tool not found"))

        let noKernel = await service.execute(
            LumiToolCall(id: "no-kernel", name: "echo", arguments: "{}"),
            conversationID: conversationID
        )
        #expect(noKernel.isError)

        let kernel = KernelLumi()
        service.kernel = kernel
        let invalid = await service.execute(
            LumiToolCall(id: "invalid", name: "echo", arguments: "not-json"),
            conversationID: conversationID
        )
        #expect(invalid.isError)

        let success = await service.execute(
            LumiToolCall(id: "success", name: "echo", arguments: "{}"),
            conversationID: conversationID
        )
        #expect(success.content == "echoed")
        #expect(!success.isError)
        #expect(success.duration != nil)

        let failing = TestTool(name: "failing", error: NSError(domain: "tests", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        service.add(failing, pluginID: "tests")
        let failure = await service.execute(
            LumiToolCall(id: "failure", name: "failing", arguments: "{}"), conversationID: conversationID
        )
        #expect(failure.isError)
        #expect(failure.content.contains("boom"))
    }

    @Test("service resolves a user-facing tool description from call arguments")
    func serviceResolvesDisplayDescription() {
        let service = ToolManagerService()
        service.add(TestTool(name: "echo"), pluginID: "tests")

        let call = LumiToolCall(id: "description", name: "echo", arguments: "{}")
        #expect(service.displayDescription(for: call) == "Test")
        #expect(service.displayDescription(for: LumiToolCall(id: "missing", name: "missing", arguments: "{}")) == nil)
        #expect(service.displayDescription(for: LumiToolCall(id: "invalid", name: "echo", arguments: "not-json")) == nil)
    }

    @Test("service returns images attached through execution context")
    func servicePreservesImages() async {
        let service = ToolManagerService()
        service.add(TestTool(name: "image", attachesImage: true), pluginID: "tests")
        let kernel = KernelLumi()
        service.kernel = kernel

        let result = await service.execute(
            LumiToolCall(id: "image-call", name: "image", arguments: "{}"),
            conversationID: UUID()
        )
        #expect(result.imageAttachments.count == 1)
        #expect(result.imageAttachments.first?.fileName == "test.png")
    }

    @Test("service preserves structured turn suspension control")
    func servicePreservesTurnSuspension() async {
        let service = ToolManagerService()
        let conversationID = UUID()
        let suspension = AgentTurnSuspension(
            suspensionID: "suspension-1",
            conversationID: conversationID,
            toolCallID: "call-1",
            kind: "userInput",
            payload: "{}"
        )
        service.add(SuspendingTool(suspension: suspension), pluginID: "tests")
        let kernel = KernelLumi()
        service.kernel = kernel

        let result = await service.execute(
            LumiToolCall(id: "call-1", name: "suspend", arguments: "{}"),
            conversationID: conversationID
        )

        #expect(result.turnControl == .suspend(suspension))
    }

    @Test("plugin exposes core tools and registers its service")
    func pluginContributions() async throws {
        let plugin = ToolManagerPlugin()
        let kernel = KernelLumi()
        #expect(plugin.id == "com.coffic.lumi.plugin.tool-manager")
        #expect(plugin.policy == .alwaysOn)
        #expect(plugin.agentTools(kernel: kernel).map(\.name) == ["ls", "glob", "read_image", "read_file", "write_file", "edit_file", "run_command", "run_subagent"])
        #expect(plugin.llmProviders(kernel: kernel).isEmpty)
        #expect(plugin.messageRenderers(kernel: kernel).isEmpty)
        #expect(plugin.menuBarContentItems(kernel: kernel).isEmpty)
        #expect(plugin.menuBarPopupItems(kernel: kernel).isEmpty)
        #expect(plugin.titleToolbarItems(kernel: kernel).isEmpty)
        #expect(plugin.panelHeaderItems(kernel: kernel).isEmpty)
        #expect(plugin.panelBottomTabItems(kernel: kernel).isEmpty)
        #expect(plugin.panelRailTabItems(kernel: kernel).isEmpty)
        #expect(plugin.statusBarItems(kernel: kernel).isEmpty)
        #expect(plugin.viewContainers(kernel: kernel).isEmpty)
        #expect(plugin.chatSectionItems(kernel: kernel).isEmpty)
        #expect(plugin.chatSectionToolbarItems(kernel: kernel).isEmpty)
        #expect(plugin.chatSectionToolbarBarItems(kernel: kernel).isEmpty)
        #expect(plugin.chatSectionHeaderItems(kernel: kernel).isEmpty)
        #expect(plugin.chatSectionActionBarItems(kernel: kernel).isEmpty)
        #expect(plugin.addSettingsView(kernel: kernel).isEmpty)
        #expect(plugin.pluginAboutView(kernel: kernel) == nil)
        #expect(plugin.llmProviderSettingsItems(kernel: kernel).isEmpty)
        #expect(plugin.llmProviderSettingsViews(kernel: kernel).isEmpty)
        #expect(plugin.rootOverlays(kernel: kernel).isEmpty)
        #expect(plugin.onboardingPages(kernel: kernel).isEmpty)
        #expect(plugin.logoItems(kernel: kernel).isEmpty)
        try await plugin.onReady(kernel: kernel)
        await plugin.onTurnFinished(kernel: kernel, conversationID: UUID(), reason: .completed)
        plugin.onContainerActivated(kernel: kernel, containerID: "test")
        await plugin.registerEditorExtensions(into: NSObject(), kernel: kernel)
        await plugin.configureEditorRuntime(kernel: kernel)
        try await plugin.onBoot(kernel: kernel)
        #expect(kernel.toolManager != nil)
    }

    @Test("agent tool errors provide localized messages")
    func agentToolErrors() {
        #expect(AgentToolError.toolNotFound(name: "missing").localizedDescription.contains("missing"))
        #expect(AgentToolError.executionFailed(name: "echo", reason: "boom").localizedDescription.contains("boom"))
    }

    @Test("tool call records can be queried by agent turn")
    func toolCallRecordsByTurn() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolCallRecordStore(databaseRootURL: directory)
        let conversationID = UUID()
        let turnID = UUID()
        let otherTurnID = UUID()
        let now = Date()

        await store.record(
            toolName: "read_file",
            toolDisplayName: "读取文件",
            turnID: turnID,
            conversationID: conversationID,
            createdAt: now,
            startedAt: now,
            completedAt: now.addingTimeInterval(0.1),
            duration: 0.1,
            argumentsJSON: "{}",
            resultContent: "first",
            resultIsError: false,
            riskLevel: "low"
        )
        await store.record(
            toolName: "shell",
            toolDisplayName: "运行命令",
            turnID: otherTurnID,
            conversationID: conversationID,
            createdAt: now,
            startedAt: now,
            completedAt: now,
            duration: 0,
            argumentsJSON: "{}",
            resultContent: "other",
            resultIsError: false,
            riskLevel: "low"
        )

        let records = await store.fetchRecords(forTurnID: turnID)
        #expect(records.count == 1)
        #expect(records.first?.toolName == "read_file")
        #expect(records.first?.turnID == turnID)
    }

    @Test("tool call results can be queried by original call ID")
    func toolCallResultByID() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolCallRecordStore(databaseRootURL: directory)
        let now = Date()
        let result = LumiToolResult(content: "result", duration: 0.2, isError: false)
        let resultJSON = String(
            data: try JSONEncoder().encode(result),
            encoding: .utf8
        )

        await store.record(
            toolCallID: "call_lookup",
            toolName: "read_file",
            toolDisplayName: "读取文件",
            conversationID: UUID(),
            createdAt: now,
            startedAt: now,
            completedAt: now,
            duration: 0.2,
            argumentsJSON: "{}",
            resultContent: result.content,
            resultJSON: resultJSON,
            resultIsError: false,
            riskLevel: "low"
        )

        let record = await store.fetchRecord(forToolCallID: "call_lookup")
        #expect(record?.toolCallID == "call_lookup")
        #expect(record?.resultJSON == resultJSON)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lumi-tool-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func temporaryURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-tool-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }

    private func temporaryFile(named name: String, contents: Data) throws -> URL {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent(name)
        try contents.write(to: fileURL)
        return fileURL
    }

    private func makeLines(count: Int, width: Int) -> Data {
        let line = String(repeating: "x", count: width) + "\n"
        var data = Data(capacity: count * (width + 1))
        for index in 0..<count {
            data.append(Data("\(index):\(line)".utf8))
        }
        return data
    }
}

private struct TestTool: LumiAgentTool {
    let id: String
    let attachesImage: Bool
    let error: Error?

    init(name: String, attachesImage: Bool = false, error: Error? = nil) {
        self.id = name
        self.attachesImage = attachesImage
        self.error = error
    }

    static let info = LumiAgentToolInfo(id: "test", displayName: "Test", description: "Test tool")

    var name: String { id }
    var toolDescription: String { "Test tool" }
    var inputSchema: LumiJSONValue { .object(["type": .string("object")]) }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        if let error { throw error }
        if attachesImage {
            kernel.attachImage(
                LumiImageAttachment(
                    mimeType: "image/png",
                    base64Data: "dGVzdA==",
                    fileName: "test.png"
                )
            )
        }
        return "echoed"
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Test"
    }
}

private struct SuspendingTool: LumiAgentTool {
    let suspension: AgentTurnSuspension

    static let info = LumiAgentToolInfo(id: "suspend", displayName: "Suspend", description: "Suspends a turn")

    var inputSchema: LumiJSONValue { .object(["type": .string("object")]) }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        "suspended"
    }

    func executeResult(
        arguments: [String: LumiJSONValue],
        kernel: KernelLumi
    ) async throws -> LumiToolExecutionResult {
        LumiToolExecutionResult(content: "suspended", turnControl: .suspend(suspension))
    }
}
