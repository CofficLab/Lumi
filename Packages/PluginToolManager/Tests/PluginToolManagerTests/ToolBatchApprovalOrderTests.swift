import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

private actor ExecutionCounter {
    private(set) var count = 0

    func record() { count += 1 }
}

/// 免授权工具：低风险，build 模式下自动执行。
private struct AutoStubTool: SuperAgentTool, @unchecked Sendable {
    let name = "batch_auto_stub"
    let counter: ExecutionCounter

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "unused" }
    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        await counter.record()
        return ToolCallResult(content: "auto-ok")
    }
}

/// 强制确认工具：无论风险高低都必须经用户确认。
private struct ApprovalStubTool: SuperAgentTool, @unchecked Sendable {
    let name = "batch_approval_stub"
    let counter: ExecutionCounter

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool { true }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "unused" }
    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        await counter.record()
        return ToolCallResult(content: "approval-ok")
    }
}

/// 回归 #149：批次契约要求保持模型给定的调用顺序，遇到第一个需要授权的
/// 调用即为暂停点，其后的调用必须等用户决定。
@MainActor
struct ToolBatchApprovalOrderTests {
    @Test("暂停点之后的免授权调用不得提前执行（回归 #149）")
    func pendingApprovalStopsSubsequentAutoCalls() async {
        let manager = ToolManager()
        let autoCounter = ExecutionCounter()
        let approvalCounter = ExecutionCounter()
        manager.add(AutoStubTool(counter: autoCounter), pluginID: "test")
        manager.add(ApprovalStubTool(counter: approvalCounter), pluginID: "test")
        let conversationID = UUID()

        let approvalCall = ToolCall(id: "a-1", name: "batch_approval_stub", arguments: "{}")
        let autoCall = ToolCall(id: "b-1", name: "batch_auto_stub", arguments: "{}")

        let results = await manager.executeBatch(
            [approvalCall, autoCall],
            policy: .requireApprovalForHighRisk,
            conversationID: conversationID,
            turnID: nil
        )

        // 修复前：观察者按授权类型分桶，免授权的 B 在 A 等待授权期间已被
        // 提前提交执行。
        #expect(results.count == 1, "授权暂停点之后的调用不得产生结果")
        if results.count == 1, case .needsUserResponse = results[0] {
        } else {
            Issue.record("暂停点结果应是授权请求")
        }
        #expect(await autoCounter.count == 0, "B 不得在 A 等待授权期间执行")
        #expect(await approvalCounter.count == 0, "A 尚未获授权，不得执行")
    }

    @Test("免授权调用先执行，随后在需授权调用处暂停（回归 #149）")
    func autoCallRunsBeforeApprovalPause() async {
        let manager = ToolManager()
        let autoCounter = ExecutionCounter()
        let approvalCounter = ExecutionCounter()
        manager.add(AutoStubTool(counter: autoCounter), pluginID: "test")
        manager.add(ApprovalStubTool(counter: approvalCounter), pluginID: "test")
        let conversationID = UUID()

        let autoCall = ToolCall(id: "b-1", name: "batch_auto_stub", arguments: "{}")
        let approvalCall = ToolCall(id: "a-1", name: "batch_approval_stub", arguments: "{}")
        let trailingAutoCall = ToolCall(id: "b-2", name: "batch_auto_stub", arguments: "{}")

        let results = await manager.executeBatch(
            [autoCall, approvalCall, trailingAutoCall],
            policy: .requireApprovalForHighRisk,
            conversationID: conversationID,
            turnID: nil
        )

        #expect(results.count == 2, "批次应在第二个调用处暂停")
        if results.count == 2, case .executed = results[0] {
        } else {
            Issue.record("首个免授权调用应已执行")
        }
        if results.count == 2, case .needsUserResponse = results[1] {
        } else {
            Issue.record("第二个调用应产生授权请求")
        }
        #expect(await autoCounter.count == 1, "暂停点之后的免授权调用不得执行")
        #expect(await approvalCounter.count == 0, "未获授权的调用不得执行")
    }
}
