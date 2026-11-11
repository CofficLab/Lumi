import Foundation
import Testing
@testable import KitLLM

/// Anthropic 的 `tool_use.input` 必须保留 JSON 空值。
///
/// ## 为什么要有这条测试
///
/// Anthropic 兼容的响应解码器逐个尝试整数 / 浮点 / 字符串 / 布尔 / 字典 /
/// 数组解码，却从不处理 `decodeNil()`——JSON `null` 全部落到兜底的
/// `value = ""`。
///
/// 结果是工具调用照常发出，但参数里已经没有模型返回的值了：
/// `{"value":null,"nested":{"optional":null},"items":[null]}` 变成
/// `{"value":"","nested":{"optional":""},"items":[""]}`。
///
/// 用 `null` 表示「缺省 / 清空可选字段」的 Anthropic 工具会收到字符串，
/// 严格校验会失败，宽松校验则可能执行与模型意图不同的操作。
@Suite("Anthropic tool_use 的空值参数")
struct AnthropicToolUseNullArgumentsTests {

    private func adapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/messages"
            )
        )
    }

    /// 解析出的参数 JSON。
    private func parsedArguments(_ json: String) throws -> [String: Any] {
        let payload = Data("""
        {"content":[{"type":"tool_use","id":"call_1","name":"update_record","input":\(json)}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)
        let call = try #require(parsed.toolCalls?.first, "应解析出工具调用")
        let argumentsData = try #require(
            JSONSerialization.jsonObject(with: Data(call.arguments.utf8)) as? [String: Any],
            "参数应是合法 JSON 对象"
        )
        return argumentsData
    }

    @Test("顶层 null 参数保持为 JSON null")
    func topLevelNullStaysNull() throws {
        let arguments = try parsedArguments(#"{"value":null}"#)

        #expect(
            arguments["value"] is NSNull,
            "null 参数应保持为空值，实际 \(String(describing: arguments["value"]))"
        )
    }

    @Test("嵌套字典里的 null 保持为 JSON null")
    func nestedNullStaysNull() throws {
        let arguments = try parsedArguments(#"{"nested":{"optional":null}}"#)

        let nested = arguments["nested"] as? [String: Any]
        #expect(
            nested?["optional"] is NSNull,
            "嵌套的 null 应保持为空值，实际 \(String(describing: nested?["optional"]))"
        )
    }

    @Test("数组里的 null 保持为 JSON null")
    func arrayNullStaysNull() throws {
        let arguments = try parsedArguments(#"{"items":[null]}"#)

        let items = arguments["items"] as? [Any]
        #expect(items?.count == 1)
        #expect(
            items?.first is NSNull,
            "数组里的 null 应保持为空值，实际 \(String(describing: items?.first))"
        )
    }

    @Test("非空值不受影响")
    func regularValuesUnchanged() throws {
        let arguments = try parsedArguments(#"{"name":"a","count":2,"flag":true}"#)

        #expect(arguments["name"] as? String == "a")
        #expect(arguments["count"] as? Int == 2)
        #expect(arguments["flag"] as? Bool == true)
    }
}
