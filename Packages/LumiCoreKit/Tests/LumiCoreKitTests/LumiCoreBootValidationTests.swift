import Foundation
import LumiCoreKit
import Testing

// MARK: - Mock Agent Tool

/// 用于测试的轻量级 Agent Tool mock
private struct MockBootTool: LumiAgentTool, @unchecked Sendable {
    let toolName: String

    static var info: LumiAgentToolInfo {
        LumiAgentToolInfo(id: "mock-boot-tool", displayName: "Mock Boot Tool", description: "Test tool for boot validation")
    }

    var name: String { toolName }

    var toolDescription: String { "Mock tool: \(toolName)" }

    var inputSchema: LumiJSONValue {
        .object(["type": .string("object")])
    }

    func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        "mock-result"
    }

    func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .low
    }
}

// MARK: - Mock Provider (class-only protocol)

/// 用于测试的 mock provider，提供自定义工具列表
private final class MockBootProvider: LumiAgentToolProviding {
    let tools: [any LumiAgentTool]

    init(tools: [any LumiAgentTool]) {
        self.tools = tools
    }

    func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        tools
    }

    func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
        []
    }
}

// MARK: - Tests

@MainActor
struct LumiCoreBootValidationTests {
    /// 启动期工具名校验：无重复工具时应正常通过
    @Test func bootWithUniqueToolsShouldPass() throws {
        let provider = MockBootProvider(tools: [
            MockBootTool(toolName: "tool_a"),
            MockBootTool(toolName: "tool_b"),
            MockBootTool(toolName: "tool_c")
        ])

        // 创建 LumiCore 实例
        let core = LumiCore()

        // 直接调用校验逻辑，模拟 boot 阶段的行为
        let tools = provider.agentTools(context: core.makePluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        ))

        // 不应抛出错误
        try LumiToolNameDeduplication.validateUnique(tools: tools)
    }

    /// 启动期工具名校验：有重复工具时应抛出 LumiToolRegistrationError
    @Test func bootWithDuplicateToolsShouldThrow() {
        let provider = MockBootProvider(tools: [
            MockBootTool(toolName: "duplicate_tool"),
            MockBootTool(toolName: "unique_tool"),
            MockBootTool(toolName: "duplicate_tool")  // 重复
        ])

        let core = LumiCore()
        let tools = provider.agentTools(context: core.makePluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        ))

        #expect(throws: LumiToolRegistrationError.self) {
            try LumiToolNameDeduplication.validateUnique(tools: tools)
        }
    }

    /// 启动期工具名校验：错误信息应包含重复的工具名
    @Test func bootValidationErrorShouldContainToolName() throws {
        let duplicateName = "my_duplicate_tool"
        let provider = MockBootProvider(tools: [
            MockBootTool(toolName: duplicateName),
            MockBootTool(toolName: duplicateName)
        ])

        let core = LumiCore()
        let tools = provider.agentTools(context: core.makePluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        ))

        do {
            try LumiToolNameDeduplication.validateUnique(tools: tools)
            Issue.record("Expected LumiToolRegistrationError to be thrown")
        } catch let error as LumiToolRegistrationError {
            let description = error.localizedDescription
            #expect(description.contains(duplicateName), "Error should contain tool name '\(duplicateName)'")
        } catch {
            Issue.record("Expected LumiToolRegistrationError, got \(type(of: error))")
        }
    }
}
