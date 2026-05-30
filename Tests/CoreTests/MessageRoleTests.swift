#if canImport(XCTest)
import XCTest
import LumiCoreKit
@testable import Lumi

/// 消息角色（MessageRole）单元测试
///
/// 验证 `MessageRole` 枚举的原始值映射和 Codable 编解码行为。
/// `MessageRole` 是聊天系统中消息类型的核心枚举，决定了消息在 UI 中的展示方式
/// 以及是否作为上下文发送给 LLM。
final class MessageRoleTests: XCTestCase {

    // MARK: - RawValue

    /// 验证每个枚举成员的 rawValue 与预期字符串一致。
    ///
    /// rawValue 用于持久化存储（SwiftData 中 `_role` 字段）和网络传输，
    /// 任何值变更都会导致已存储数据解析失败，因此必须保持稳定。
    func testRawValues() {
        XCTAssertEqual(LumiCoreKit.MessageRole.user.rawValue, "user")
        XCTAssertEqual(LumiCoreKit.MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(LumiCoreKit.MessageRole.system.rawValue, "system")
        XCTAssertEqual(LumiCoreKit.MessageRole.tool.rawValue, "tool")
        XCTAssertEqual(LumiCoreKit.MessageRole.status.rawValue, "status")
        XCTAssertEqual(LumiCoreKit.MessageRole.error.rawValue, "error")
        XCTAssertEqual(LumiCoreKit.MessageRole.unknown.rawValue, "unknown")
    }

    // MARK: - Codable

    /// 验证从 JSON 字符串数组可以正确解码出所有 MessageRole 值。
    ///
    /// 这模拟了从持久化层或 API 响应中反序列化角色的场景，
    /// 确保所有合法 rawValue 都能被正确识别。
    func testDecodingValidRoles() throws {
        let json = """
        ["user", "assistant", "system", "tool", "status", "error", "unknown"]
        """.data(using: .utf8)!

        let roles = try JSONDecoder().decode([LumiCoreKit.MessageRole].self, from: json)

        XCTAssertEqual(roles, [
            LumiCoreKit.MessageRole.user,
            .assistant,
            .system,
            .tool,
            .status,
            .error,
            .unknown,
        ])
    }

    /// 验证编码后的 JSON 字符串与 rawValue 一致。
    ///
    /// 确保序列化输出不会引入额外的引号、转义或格式偏差。
    func testEncodingPreservesRawValue() throws {
        let encoded = try JSONEncoder().encode(LumiCoreKit.MessageRole.user)
        let string = String(data: encoded, encoding: .utf8)

        XCTAssertEqual(string, #""user""#)
    }
}
#endif
