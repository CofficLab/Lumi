import Foundation
import Testing
@testable import KitAgentTool

private struct LegacyContextTool: SuperAgentTool {
    let name = "legacy_context_tool"

    func description(for language: LanguagePreference) -> String { "Legacy" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Legacy execution" }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        "legacy-result"
    }
}

private actor ExecutionEventRecorder {
    private(set) var outputs: [(ToolExecutionOutputStream, String)] = []
    private(set) var progresses: [ToolExecutionProgress] = []

    func recordOutput(_ stream: ToolExecutionOutputStream, chunk: String) {
        outputs.append((stream, chunk))
    }

    func recordProgress(_ progress: ToolExecutionProgress) {
        progresses.append(progress)
    }
}

private struct ContextAwareTool: SuperAgentTool {
    let name = "context_aware_tool"

    func description(for language: LanguagePreference) -> String { "Context aware" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Context execution" }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard !context.isCancelled() else {
            return ToolCallResult(content: "cancelled", isError: true)
        }

        await context.reportOutput(.stdout, "working")
        await context.reportProgress(
            ToolExecutionProgress(message: "Halfway", completed: 1, total: 2, fraction: 0.5)
        )
        return ToolCallResult(content: "context-result")
    }
}

struct ToolExecutionContextTests {
    @Test("旧工具通过默认 Context 实现仍返回原文本结果")
    func legacyToolUsesDefaultContextImplementation() async throws {
        let context = ToolExecutionContext(
            jobID: "job-1",
            conversationID: UUID()
        )

        let result = try await LegacyContextTool().executeResult(
            context: context,
            arguments: [:]
        )

        #expect(result.content == "legacy-result")
        #expect(!result.isError)
    }

    @Test("新工具可以通过 Context 上报输出和进度")
    func contextAwareToolReportsOutputAndProgress() async throws {
        let recorder = ExecutionEventRecorder()
        let context = ToolExecutionContext(
            jobID: "job-2",
            conversationID: UUID(),
            isCancelled: { false },
            reportOutput: { stream, chunk in
                await recorder.recordOutput(stream, chunk: chunk)
            },
            reportProgress: { progress in
                await recorder.recordProgress(progress)
            }
        )

        let result = try await ContextAwareTool().executeResult(
            context: context,
            arguments: [:]
        )
        let outputs = await recorder.outputs
        let progresses = await recorder.progresses

        #expect(result.content == "context-result")
        #expect(outputs.count == 1)
        #expect(outputs.first?.0 == .stdout)
        #expect(outputs.first?.1 == "working")
        #expect(progresses == [
            ToolExecutionProgress(message: "Halfway", completed: 1, total: 2, fraction: 0.5)
        ])
    }
}
