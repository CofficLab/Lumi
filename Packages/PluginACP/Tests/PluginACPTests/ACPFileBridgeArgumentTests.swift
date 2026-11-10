import Foundation
import KitAgentTool
import Testing
@testable import PluginACP

/// ACP 文件桥的参数解析必须先检查范围再转换。
///
/// JSON 数字会桥接成 `Double`，而 `Int(_:)` 对超出 `Int` 范围的 `Double`
/// 会触发 Swift 运行时陷阱（precondition failure），直接终止宿主进程。
/// 一个完全合法的 JSON 参数就能让应用崩溃。
@Suite("ACP 文件桥参数解析")
struct ACPFileBridgeArgumentTests {

    @Test("超大 limit 返回 nil 而不是崩溃")
    func oversizedLimitReturnsNil() {
        let arguments: [String: ToolArgument] = [
            "path": ToolArgument("/tmp/example.txt"),
            "limit": ToolArgument(1e100 as Any),
        ]
        // 旧实现：`Int(1e100)` 直接 trap。
        #expect(arguments.intValue("limit") == nil)
    }

    @Test("超大 line 返回 nil 而不是崩溃")
    func oversizedLineReturnsNil() {
        let arguments: [String: ToolArgument] = [
            "path": ToolArgument("/tmp/example.txt"),
            "line": ToolArgument(1e100 as Any),
        ]
        #expect(arguments.intValue("line") == nil)
    }

    @Test("非有限值返回 nil")
    func nonFiniteReturnsNil() {
        let arguments: [String: ToolArgument] = [
            "limit": ToolArgument(Double.infinity as Any),
            "line": ToolArgument(Double.nan as Any),
        ]
        #expect(arguments.intValue("limit") == nil)
        #expect(arguments.intValue("line") == nil)
    }

    @Test("范围内的整数正常解析")
    func inRangeIntegersParse() {
        let arguments: [String: ToolArgument] = [
            "line": ToolArgument(10),
            "limit": ToolArgument(25.0 as Any),
            "text": ToolArgument("5"),
        ]
        #expect(arguments.intValue("line") == 10)
        #expect(arguments.intValue("limit") == 25)
        #expect(arguments.intValue("text") == 5)
    }

    @Test("缺失或非数值参数返回 nil")
    func missingOrNonNumericReturnsNil() {
        let arguments: [String: ToolArgument] = [
            "name": ToolArgument("abc"),
        ]
        #expect(arguments.intValue("missing") == nil)
        #expect(arguments.intValue("name") == nil)
    }
}
