import Foundation
import LumiCoreKit
import Testing

// MARK: - 测试用 Mock

/// 用于 `LumiToolNameDeduplicationTests` 的轻量 mock 工具。
/// name 通过构造参数注入，类型名固定以便断言 `owners` 内容。
private struct DupMockTool: LumiAgentTool, @unchecked Sendable {
    let toolName: String

    static var info: LumiAgentToolInfo {
        LumiAgentToolInfo(id: "dup-mock", displayName: "Dup Mock", description: "Dup Mock")
    }

    var name: String { toolName }
    var toolDescription: String { "dup mock" }

    var inputSchema: LumiJSONValue {
        .object(["type": .string("object")])
    }

    func execute(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext
    ) async throws -> String {
        "ok"
    }

    func riskLevel(
        arguments: [String: LumiJSONValue],
        context: LumiToolExecutionContext?
    ) -> LumiCommandRiskLevel {
        .low
    }
}

// MARK: - 测试

struct LumiToolNameDeduplicationTests {
    /// 唯一名称列表应通过校验，不抛错。
    @Test func uniqueNamesPassesValidation() throws {
        let tools: [any LumiAgentTool] = [
            DupMockTool(toolName: "alpha"),
            DupMockTool(toolName: "beta"),
            DupMockTool(toolName: "gamma"),
        ]

        // 不抛错即通过
        try LumiToolNameDeduplication.validateUnique(tools: tools)
    }

    /// 重复名称应抛 `LumiToolRegistrationError.duplicateNames`，
    /// 错误内含所有冲突工具类型。
    @Test func duplicateNamesThrowsWithOwnerTypes() {
        let tools: [any LumiAgentTool] = [
            DupMockTool(toolName: "conversation_info"),
            DupMockTool(toolName: "alpha"),
            DupMockTool(toolName: "conversation_info"), // 重复
        ]

        #expect(throws: LumiToolRegistrationError.self) {
            try LumiToolNameDeduplication.validateUnique(tools: tools)
        }
    }

    /// 抛出的错误应携带工具名和两个 owner 类型名（按出现顺序）。
    @Test func duplicateErrorExposesOwners() {
        let tools: [any LumiAgentTool] = [
            DupMockTool(toolName: "conversation_info"),
            DupMockTool(toolName: "conversation_info"),
        ]

        do {
            try LumiToolNameDeduplication.validateUnique(tools: tools)
            Issue.record("Expected LumiToolRegistrationError but no error was thrown")
        } catch let error as LumiToolRegistrationError {
            guard case .duplicateNames(let entries) = error else {
                Issue.record("Expected .duplicateNames case, got \(error)")
                return
            }

            #expect(entries.count == 1)
            guard let entry = entries.first else {
                Issue.record("entries.first should not be nil")
                return
            }
            #expect(entry.name == "conversation_info")
            // `String(reflecting:)` 含模块名；至少能看到 mock 类型名。
            #expect(entry.owners.count == 2)
            #expect(entry.owners.allSatisfy { $0.contains("DupMockTool") })

            // errorDescription 应包含工具名，便于 CrashedView / 日志展示。
            let desc = error.errorDescription ?? ""
            #expect(desc.contains("conversation_info"))
        } catch {
            Issue.record("Expected LumiToolRegistrationError, got \(error)")
        }
    }

    /// 空列表应直接通过。
    @Test func emptyToolsPassesValidation() throws {
        try LumiToolNameDeduplication.validateUnique(tools: [])
    }
}
