import Foundation
@testable import PluginProjectRAG
import KitAgentTool
import Testing

@Suite("RAGGrepTool", .serialized)
@MainActor
struct RAGGrepToolTests {

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-grep-tool-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeNeedleFixture() throws -> URL {
        let dir = try makeTempDir()
        let lines = (1...10).map { "line \($0) needle" }.joined(separator: "\n")
        try (lines + "\n").write(
            to: dir.appendingPathComponent("Needle.swift"), atomically: true, encoding: .utf8
        )
        return dir
    }

    private func makeContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    private func matchLineCount(_ output: String) -> Int {
        output.split(separator: "\n").filter { $0.contains("Needle.swift:") }.count
    }

    @Test("missing pattern throws")
    func missingPatternThrows() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGGrepTool().execute(arguments: [:])
        }
    }

    @Test("nonexistent path throws")
    func nonexistentPathThrows() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-grep-missing-\(UUID().uuidString)").path
        do {
            _ = try await RAGGrepTool().execute(arguments: [
                "pattern": ToolArgument("needle"),
                "path": ToolArgument(missing),
            ])
            Issue.record("expected ToolExecutionError")
        } catch let error as ToolExecutionError {
            guard case let .executionFailed(_, reason) = error else {
                Issue.record("unexpected case: \(error)")
                return
            }
            #expect(reason.contains(missing))
        }
    }

    @Test("missing project context throws")
    func missingProjectThrows() async throws {
        ProjectRAGRuntime.reset()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGGrepTool().execute(arguments: ["pattern": ToolArgument("needle")])
        }
    }

    @Test("no match returns informational string")
    func noMatchReturnsInformationalString() async throws {
        let dir = try makeNeedleFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let output = try await RAGGrepTool().execute(arguments: [
            "pattern": ToolArgument("zzzNothingMatches"),
            "path": ToolArgument(dir.path),
        ])
        #expect(output.contains("No matches"))
        #expect(!output.contains("Error"))
    }

    @Test("max_results is clamped to the schema range")
    func maxResultsClampedToSchemaRange() async throws {
        let dir = try makeNeedleFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let tool = RAGGrepTool()

        let low = try await tool.execute(arguments: [
            "pattern": ToolArgument("needle"), "path": ToolArgument(dir.path), "max_results": ToolArgument(-5),
        ])
        #expect(matchLineCount(low) == 1)
        #expect(low.contains("[truncated:"))

        let high = try await tool.execute(arguments: [
            "pattern": ToolArgument("needle"), "path": ToolArgument(dir.path), "max_results": ToolArgument(9999),
        ])
        #expect(matchLineCount(high) == 10)

        let invalid = try await tool.execute(arguments: [
            "pattern": ToolArgument("needle"), "path": ToolArgument(dir.path), "max_results": ToolArgument("abc"),
        ])
        #expect(matchLineCount(invalid) == 10)
    }

    @Test("explicit path beats conversation project")
    func explicitPathBeatsConversationProject() async throws {
        let dir = try makeNeedleFixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-grep-bogus-\(UUID().uuidString)").path

        let output = try await RAGGrepTool().executeResult(
            context: makeContext(projectPath: bogus),
            arguments: [
                "pattern": ToolArgument("needle"),
                "path": ToolArgument(dir.path),
            ]
        )
        #expect(output.content.contains("Needle.swift:"))
    }

    @Test("conversation project used when no explicit path")
    func conversationProjectUsedWhenNoExplicitPath() async throws {
        let dir = try makeNeedleFixture()
        defer { try? FileManager.default.removeItem(at: dir) }

        let output = try await RAGGrepTool().executeResult(
            context: makeContext(projectPath: dir.path),
            arguments: ["pattern": ToolArgument("needle")]
        )
        #expect(output.content.contains("Needle.swift:"))
    }

    @Test("context_lines adds surrounding lines")
    func contextLinesAddsSurroundingLines() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "alpha\nneedle\nomega\n".write(
            to: dir.appendingPathComponent("Ctx.swift"), atomically: true, encoding: .utf8
        )
        let output = try await RAGGrepTool().execute(arguments: [
            "pattern": ToolArgument("needle"),
            "path": ToolArgument(dir.path),
            "context_lines": ToolArgument(1),
        ])
        #expect(output.contains("Ctx.swift-1-alpha"))
        #expect(output.contains("Ctx.swift:2:needle"))
        #expect(output.contains("Ctx.swift-3-omega"))
    }
}