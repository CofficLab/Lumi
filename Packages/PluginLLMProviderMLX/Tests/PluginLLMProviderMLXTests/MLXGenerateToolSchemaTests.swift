import Foundation
import KitLLM
import Testing
import MLXLMCommon
@testable import PluginLLMProviderMLX

/// MLX 生成阶段必须拿到工具 Schema，才能做参数类型解析与函数名授权。
///
/// ## 为什么要有这条测试
///
/// `mlx-swift-lm` 里工具 Schema 有**两个**互不替代的用途：
/// - `UserInput(chat:tools:)`：给 chat template 渲染提示词；
/// - `ModelContainer.generate(..., tools:)`：给响应解析层做参数类型解析与
///   函数名授权。
///
/// `MLXRuntime` 只填了前者，后者用默认值 `nil`。而 `nil` 的语义是
/// 「接受任意解析出的函数名，且不做 Schema 类型转换」：
/// - Schema 里声明为 `integer` 的参数保持字符串 `"1"`；
/// - 模型输出未声明的函数名也不会被拒绝。
///
/// 结果是错误的参数类型流进后续 Agent 工具链。
@Suite("MLX 生成阶段的工具 Schema")
struct MLXGenerateToolSchemaTests {

    /// 构造一份与 MLX 依赖 API 形状一致的工具 Schema。
    private func makeTools() -> [[String: any Sendable]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "search",
                    "description": "Search the web",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "page": ["type": "integer"] as [String: any Sendable],
                        ] as [String: any Sendable],
                    ] as [String: any Sendable],
                ] as [String: any Sendable],
            ]
        ]
    }

    /// Qwen XML 工具格式的帧标签。
    ///
    /// 取自上游 `ToolCallFormat.xmlFunction` 的真实值——标签里含零宽字符，
    /// 手写容易对不上。
    private let qwenStartTag = "<tool_call>"
    private let qwenEndTag = "</tool_call>"

    /// Qwen XML 工具格式的调用片段。
    private func qwenXMLToolCall(name: String, page: String) -> String {
        "\(qwenStartTag)<function=\(name)><parameter=page>\(page)</parameter></function>\(qwenEndTag)"
    }

    /// 解析出工具调用的参数。
    private func parsedArguments(
        tools: [[String: any Sendable]]?
    ) throws -> [String: JSONValue] {
        let processor = ToolCallProcessor(format: .xmlFunction, tools: tools)
        let outputs = processor.processChunkOutputs(qwenXMLToolCall(name: "search", page: "1"))

        let call = try #require(
            outputs.compactMap { output -> MLXLMCommon.ToolCall? in
                if case let .toolCall(call) = output { return call }
                return nil
            }.first,
            "应解析出工具调用"
        )
        return call.function.arguments
    }

    @Test("工具 Schema 让响应解析按声明的类型转换参数")
    func toolSchemaEnablesTypedArgumentParsing() throws {
        let arguments = try parsedArguments(tools: makeTools())

        #expect(
            arguments["page"] == .int(1),
            "声明为 integer 的参数应转成整数，实际 \(String(describing: arguments["page"]))"
        )
    }

    @Test("没有工具 Schema 时参数不做类型转换")
    func noToolSchemaLeavesArgumentsUntyped() throws {
        // 这正是 `generate(..., tools: nil)` 的语义。
        let arguments = try parsedArguments(tools: nil)

        #expect(
            arguments["page"] == .string("1"),
            "没有 Schema 时参数保持原始字符串，实际 \(String(describing: arguments["page"]))"
        )
    }

    @Test("工具 Schema 拒绝未声明的函数名")
    func toolSchemaRejectsUndeclaredFunctionName() throws {
        let processor = ToolCallProcessor(format: .xmlFunction, tools: makeTools())
        let outputs = processor.processChunkOutputs(
            "\(qwenStartTag)<function=not_declared><parameter=page>1</parameter></function>\(qwenEndTag)"
        )

        let hasToolCall = outputs.contains { output in
            if case .toolCall = output { return true }
            return false
        }
        let hasRejection = outputs.contains { output in
            if case .rejectedToolCall = output { return true }
            return false
        }

        #expect(!hasToolCall, "未声明的函数名不应被授权")
        #expect(hasRejection, "未声明的函数名应被拒绝")
    }
}
