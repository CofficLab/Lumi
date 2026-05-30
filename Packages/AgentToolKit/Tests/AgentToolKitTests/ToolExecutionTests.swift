import Foundation
import Testing
@testable import AgentToolKit

private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class TestFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func setTrue() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

// MARK: - ToolExecutionContext

struct ToolExecutionContextTests {
    @Test
    func initStoresMetadata() {
        let conversationId = UUID()
        let context = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: "call_1",
            toolName: "read_file"
        )

        #expect(context.conversationId == conversationId)
        #expect(context.toolCallId == "call_1")
        #expect(context.toolName == "read_file")
        #expect(!context.isCancelled)
    }

    @Test
    func checkCancellationThrowsAfterCancel() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )

        context.cancel()

        #expect(context.isCancelled)
        #expect(throws: CancellationError.self) {
            try context.checkCancellation()
        }
    }

    @Test
    func cancelRunsRegisteredHandlers() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )
        let counter = TestCounter()

        _ = context.onCancel {
            counter.increment()
        }

        context.cancel()

        #expect(counter.count == 1)
        #expect(context.isCancelled)
    }

    @Test
    func onCancelRunsImmediatelyWhenAlreadyCancelled() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )
        let counter = TestCounter()

        context.cancel()
        let handlerId = context.onCancel {
            counter.increment()
        }

        #expect(handlerId == nil)
        #expect(counter.count == 1)
    }

    @Test
    func removeCancellationHandlerPreventsExecution() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )
        let counter = TestCounter()

        let handlerId = context.onCancel {
            counter.increment()
        }
        context.removeCancellationHandler(handlerId)
        context.cancel()

        #expect(counter.count == 0)
    }

    @Test
    func cancelIsIdempotent() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )
        let counter = TestCounter()

        _ = context.onCancel {
            counter.increment()
        }

        context.cancel()
        context.cancel()

        #expect(counter.count == 1)
    }

    @Test
    func cancelFromConcurrentTaskStillRunsHandlers() async {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "shell"
        )
        let flag = TestFlag()

        _ = context.onCancel {
            flag.setTrue()
        }

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                context.cancel()
                continuation.resume()
            }
        }

        #expect(flag.isSet)
    }

    @Test
    func isPathAllowedAcceptsAllowedDirectoryAndChildren() {
        let projectPath = "/tmp/LumiProject"
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "read_file",
            allowedDirectories: [projectPath]
        )

        #expect(context.isPathAllowed(projectPath))
        #expect(context.isPathAllowed("\(projectPath)/Sources/App.swift"))
    }

    @Test
    func isPathAllowedRejectsSiblingWithSharedPrefix() {
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "read_file",
            allowedDirectories: ["/tmp/LumiProject"]
        )

        #expect(!context.isPathAllowed("/tmp/LumiProjectBackup/Secrets.swift"))
        #expect(!context.isPathAllowed("/tmp/LumiProject2/Secrets.swift"))
    }

    @Test
    func isPathAllowedTrimsCopiedPathWhitespace() {
        let projectPath = "/tmp/LumiProject"
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: "read_file",
            allowedDirectories: [" \(projectPath)/ \n"]
        )

        #expect(context.isPathAllowed(" \n\(projectPath)/Sources/App.swift\t"))
    }

    @Test
    func resolvePathPreservesRootDirectory() {
        #expect(ToolExecutionContext.resolvePath("/") == "/")
    }
}

// MARK: - SuperAgentTool

struct SuperAgentToolTests {
    @Test
    func defaultDescriptionUsesEnglish() {
        let tool = MockAgentTool(
            englishDescription: "Read a file",
            chineseDescription: "读取文件"
        )

        #expect(tool.description == "Read a file")
    }

    @Test
    func defaultInputSchemaUsesEnglish() {
        let tool = MockAgentTool()
        let schema = tool.inputSchema

        #expect(schema["lang"] as? String == "en")
    }

    @Test
    func executeReturnsUnderlyingResult() async throws {
        let tool = MockAgentTool(result: "file contents")
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)
        let result = try await tool.execute(arguments: [:], context: context)

        #expect(result == "file contents")
    }

    @Test
    func executeWithContextThrowsWhenCancelledBeforeExecution() async {
        let tool = MockAgentTool(result: "unused")
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: tool.name
        )
        context.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await tool.execute(arguments: [:], context: context)
        }
    }

    @Test
    func executeWithContextThrowsWhenCancelledAfterExecution() async {
        let tool = MockAgentTool(
            result: "done",
            executeDelayNanoseconds: 50_000_000
        )
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: tool.name
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    _ = try await tool.execute(arguments: [:], context: context)
                } catch is CancellationError {
                    // expected
                } catch {
                    Issue.record("Unexpected error: \(error)")
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000)
                context.cancel()
            }
        }

        #expect(context.isCancelled)
    }

    @Test
    func permissionRiskLevelDelegatesToImplementation() {
        let tool = MockAgentTool(risk: .high)
        #expect(tool.permissionRiskLevel(arguments: [:]) == .high)
    }
}

// MARK: - LocalizedAgentTool

struct LocalizedAgentToolTests {
    @Test
    func nameMatchesUnderlyingTool() {
        let underlying = MockAgentTool(name: "read_file")
        let localized = LocalizedAgentTool(underlying: underlying, language: .chinese)

        #expect(localized.name == "read_file")
    }

    @Test
    func descriptionUsesWrappedLanguageRegardlessOfRequestedLanguage() {
        let underlying = MockAgentTool(
            englishDescription: "English",
            chineseDescription: "中文"
        )
        let localized = LocalizedAgentTool(underlying: underlying, language: .chinese)

        #expect(localized.description(for: .english) == "中文")
        #expect(localized.description(for: .chinese) == "中文")
    }

    @Test
    func inputSchemaUsesWrappedLanguage() {
        let underlying = MockAgentTool()
        let localized = LocalizedAgentTool(underlying: underlying, language: .chinese)

        #expect(localized.inputSchema(for: .english)["lang"] as? String == "zh")
    }

    @Test
    func executeDelegatesToUnderlyingTool() async throws {
        let underlying = MockAgentTool(result: "payload")
        let localized = LocalizedAgentTool(underlying: underlying, language: .english)
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: localized.name)

        let result = try await localized.execute(arguments: [:], context: context)
        #expect(result == "payload")
    }

    @Test
    func executeInjectsWrappedLanguage() async throws {
        let underlying = MockAgentTool { arguments in
            arguments["__lumi_language"]?.value as? String ?? "missing"
        }
        let localized = LocalizedAgentTool(underlying: underlying, language: .chinese)
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: localized.name)

        let result = try await localized.execute(arguments: [:], context: context)
        #expect(result == "zh")
    }

    @Test
    func executeWithContextDelegatesToUnderlyingTool() async throws {
        let underlying = MockAgentTool(result: "payload")
        let localized = LocalizedAgentTool(underlying: underlying, language: .english)
        let context = ToolExecutionContext(
            conversationId: UUID(),
            toolCallId: "call_1",
            toolName: localized.name
        )

        let result = try await localized.execute(arguments: [:], context: context)
        #expect(result == "payload")
    }

    @Test
    func permissionRiskLevelDelegatesToUnderlyingTool() {
        let underlying = MockAgentTool(risk: .medium)
        let localized = LocalizedAgentTool(underlying: underlying, language: .english)

        #expect(localized.permissionRiskLevel(arguments: [:]) == .medium)
    }
}
