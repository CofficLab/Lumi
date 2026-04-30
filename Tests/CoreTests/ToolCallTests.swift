#if canImport(XCTest)
import XCTest
@testable import Lumi

/// 工具调用（ToolCall）单元测试
///
/// 验证 `ToolCall` 模型的核心行为：
/// - **Equatable**：基于 id、name、arguments 的相等性判断
/// - **Codable**：JSON 编解码往返，包括 authorizationState 的兼容性处理
/// - **默认值**：新建 ToolCall 的授权状态默认为 pendingAuthorization
///
/// `ToolCall` 表示 AI 助手请求执行工具/函数的调用，是 Agent 工作流中的关键数据结构。
final class ToolCallTests: XCTestCase {

    // MARK: - Equality

    /// 验证 id、name、arguments 完全相同的两个 ToolCall 判定为相等。
    func testEquality_sameProperties() {
        let a = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        let b = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        XCTAssertEqual(a, b)
    }

    /// 验证 id 不同时两个 ToolCall 判定为不等。
    ///
    /// 即使 name 和 arguments 相同，不同的 id 代表不同的调用实例。
    func testEquality_differentId() {
        let a = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        let b = ToolCall(id: "call_2", name: "read_file", arguments: "{}")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable Round-Trip

    /// 验证 ToolCall 经过 JSON 编码→解码后所有字段完整保留。
    ///
    /// 这覆盖了正常场景：包含 id、name、arguments 和非默认的 authorizationState。
    /// 确保 ToolCall 在持久化和 API 通信中不会丢失信息。
    func testCodableRoundTrip() throws {
        let original = ToolCall(
            id: "call_abc",
            name: "write_file",
            arguments: #"{"path":"/tmp/test.swift","content":"hello"}"#,
            authorizationState: .authorized
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.arguments, original.arguments)
        XCTAssertEqual(decoded.authorizationState, original.authorizationState)
    }

    /// 验证从旧版 JSON（不含 authorizationState 字段）解码时，默认回退为 pendingAuthorization。
    ///
    /// 这是一个向前兼容性测试：旧版本 API 或持久化数据中可能没有 authorizationState 字段，
    /// 解码时应安全降级，而不是抛出解码错误。
    func testDecodingWithoutAuthorizationState_defaultsToPending() throws {
        let json = """
        {"id":"call_1","name":"read_file","arguments":"{}"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ToolCall.self, from: json)

        XCTAssertEqual(decoded.authorizationState, .pendingAuthorization)
    }

    // MARK: - Default Authorization State

    /// 验证新建 ToolCall 时，authorizationState 默认为 pendingAuthorization。
    ///
    /// 这确保所有新创建的工具调用都需要经过用户授权才能执行，
    /// 是安全模型的一部分。
    func testDefaultAuthorizationStateIsPending() {
        let toolCall = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        XCTAssertEqual(toolCall.authorizationState, .pendingAuthorization)
    }
}
#endif
