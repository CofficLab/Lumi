#if canImport(XCTest)
import XCTest
@testable import Lumi

/// 聊天模式（ChatMode）单元测试
///
/// 验证 `ChatMode` 枚举的各项属性，该枚举决定了用户在对话中的意图和权限：
/// - **chat（对话模式）**：只聊天，不允许执行任何工具或修改代码
/// - **build（构建模式）**：可以执行工具、修改代码等完整能力
///
/// 测试覆盖：
/// - 枚举完备性（CaseIterable）
/// - rawValue 持久化值
/// - 工具权限控制（allowsTools）
/// - UI 展示属性（displayName、iconName 等）
/// - Codable 编解码往返
final class ChatModeTests: XCTestCase {

    // MARK: - RawValue & CaseIterable

    /// 验证 ChatMode 包含且仅包含 chat 和 build 两个成员。
    ///
    /// 如果新增模式（如 "agent"），此测试会失败，提醒开发者同步更新相关逻辑。
    func testAllCases() {
        XCTAssertEqual(ChatMode.allCases.count, 2)
        XCTAssertTrue(ChatMode.allCases.contains(.chat))
        XCTAssertTrue(ChatMode.allCases.contains(.build))
    }

    /// 验证 rawValue 与字符串标识一致。
    ///
    /// rawValue 用于持久化和网络传输，变更会导致已存储数据无法正确解析。
    func testRawValues() {
        XCTAssertEqual(ChatMode.chat.rawValue, "chat")
        XCTAssertEqual(ChatMode.build.rawValue, "build")
    }

    // MARK: - allowsTools

    /// chat 模式下不允许使用工具，确保纯对话场景的安全性。
    func testChatModeDoesNotAllowTools() {
        XCTAssertFalse(ChatMode.chat.allowsTools)
    }

    /// build 模式下允许使用工具，用于代码读写、命令执行等操作。
    func testBuildModeAllowsTools() {
        XCTAssertTrue(ChatMode.build.allowsTools)
    }

    // MARK: - Display Properties

    /// 验证中文显示名称，用于 UI 模式切换器。
    func testDisplayNames() {
        XCTAssertEqual(ChatMode.chat.displayName, "对话")
        XCTAssertEqual(ChatMode.build.displayName, "构建")
    }

    /// 验证英文显示名称，用于国际化场景。
    func testDisplayNamesEn() {
        XCTAssertEqual(ChatMode.chat.displayNameEn, "Chat")
        XCTAssertEqual(ChatMode.build.displayNameEn, "Build")
    }

    /// 验证 SF Symbols 图标名称，用于 UI 模式切换器图标。
    func testIconNames() {
        XCTAssertEqual(ChatMode.chat.iconName, "bubble.left.and.bubble.right")
        XCTAssertEqual(ChatMode.build.iconName, "hammer.fill")
    }

    // MARK: - Codable

    /// 验证所有模式经过编码→解码往返后值不变。
    ///
    /// 这确保了 ChatMode 在持久化（如 UserDefaults、SwiftData）
    /// 和网络传输（JSON）中的序列化稳定性。
    func testRoundTripEncoding() throws {
        for mode in ChatMode.allCases {
            let encoded = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(ChatMode.self, from: encoded)
            XCTAssertEqual(decoded, mode)
        }
    }
}
#endif
