import Foundation
import KitAgentTool
import Testing
@testable import ProviderAgentLoop

/// 子会话工具表的共享过滤契约（#1313 Task 3）。
///
/// 端到端行为由 FactoryLumi 的 SubagentEndToEndTests 锁定；这里直接
/// 对 `SubagentToolPolicy.childTools` 做单元级断言，保证过滤规则本身
/// 不被上游组装逻辑的变化掩盖。
@MainActor
@Suite("SubagentToolPolicy 子会话工具过滤")
struct SubagentToolPolicyTests {

    /// 可指定执行能力的最小工具替身。
    private final class CapabilityTool: SuperAgentTool, @unchecked Sendable {
        let name: String
        let capability: ToolExecutionCapability

        init(name: String, capability: ToolExecutionCapability) {
            self.name = name
            self.capability = capability
        }

        var executionCapability: ToolExecutionCapability { capability }
        func description(for language: LanguagePreference) -> String { name }
        func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }
        func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
        func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
        func execute(arguments: [String: ToolArgument]) async throws -> String { "ok" }
    }

    @Test("子会话工具表不得包含委托工具自身")
    func childToolsExcludeDelegationToolItself() {
        // 即使委托工具声明为只读并发，名字规则也必须把它挡在子表之外。
        let tools: [any SuperAgentTool] = [
            CapabilityTool(name: SubagentToolPolicy.delegationToolName, capability: .parallelReadOnly),
            CapabilityTool(name: "read_file", capability: .parallelReadOnly),
        ]
        let filtered = SubagentToolPolicy.childTools(from: tools)
        #expect(filtered.map(\.name) == ["read_file"])
    }

    @Test("子会话工具表只保留只读并发工具且保持注册顺序")
    func childToolsKeepOnlyParallelReadOnlyInOrder() {
        let tools: [any SuperAgentTool] = [
            CapabilityTool(name: "write_file", capability: .serialSideEffect),
            CapabilityTool(name: "grep", capability: .parallelReadOnly),
            CapabilityTool(name: "ask_user", capability: .interactive),
            CapabilityTool(name: "web_fetch", capability: .parallelReadOnly),
        ]
        let filtered = SubagentToolPolicy.childTools(from: tools)
        #expect(filtered.map(\.name) == ["grep", "web_fetch"])
    }

    @Test("空工具表过滤后仍为空")
    func childToolsOfEmptyRegistryIsEmpty() {
        #expect(SubagentToolPolicy.childTools(from: []).isEmpty)
    }
}