import Foundation
import Testing
@testable import KitAgentTool

/// 工具参数的安全数值转换。
///
/// JSON 数字会桥接成 `Double`，而 `Int(_:)` 对超出 `Int` 范围的 `Double`
/// 会触发运行时陷阱（precondition failure），直接终止宿主进程。
/// 转换必须先检查范围。
@Suite("ToolArgumentNumber")
struct ToolArgumentNumberTests {

    // MARK: - int(_:)

    @Test("整数原样返回")
    func returnsPlainInt() {
        #expect(ToolArgumentNumber.int(42) == 42)
        #expect(ToolArgumentNumber.int(-7) == -7)
        #expect(ToolArgumentNumber.int(0) == 0)
    }

    @Test("范围内的 Double 转换成功")
    func convertsFiniteDouble() {
        #expect(ToolArgumentNumber.int(3.0) == 3)
        #expect(ToolArgumentNumber.int(3.9) == 3)
        #expect(ToolArgumentNumber.int(-2.5) == -2)
    }

    @Test("超出 Int 范围的 Double 返回 nil 而不是崩溃")
    func rejectsOutOfRangeDouble() {
        // `Int(1e100)` 会 trap；这里必须返回 nil。
        #expect(ToolArgumentNumber.int(1e100) == nil)
        #expect(ToolArgumentNumber.int(-1e100) == nil)
        #expect(ToolArgumentNumber.int(Double.greatestFiniteMagnitude) == nil)
        #expect(ToolArgumentNumber.int(-Double.greatestFiniteMagnitude) == nil)
    }

    @Test("非有限 Double 返回 nil")
    func rejectsNonFiniteDouble() {
        #expect(ToolArgumentNumber.int(Double.infinity) == nil)
        #expect(ToolArgumentNumber.int(-Double.infinity) == nil)
        #expect(ToolArgumentNumber.int(Double.nan) == nil)
    }

    @Test("数字字符串可转换")
    func convertsNumericString() {
        #expect(ToolArgumentNumber.int("12") == 12)
        #expect(ToolArgumentNumber.int("  7 ") == 7)
        #expect(ToolArgumentNumber.int("abc") == nil)
    }

    @Test("非数值类型返回 nil")
    func rejectsOtherTypes() {
        #expect(ToolArgumentNumber.int(nil) == nil)
        #expect(ToolArgumentNumber.int([1, 2]) == nil)
        #expect(ToolArgumentNumber.int(["a": 1]) == nil)
        #expect(ToolArgumentNumber.int(true) == nil)
    }

    // MARK: - int(fromDouble:)

    @Test("int(fromDouble:) 对边界值安全")
    func convertsBoundaryDoubles() {
        // 不能用 `Double(Int.max)` 做边界检查 —— 那个转换本身就会 trap。
        // 用精确可表示的 2^63 - 1 以内的值验证。
        #expect(ToolArgumentNumber.int(fromDouble: 9_007_199_254_740_991.0) == 9_007_199_254_740_991)
        #expect(ToolArgumentNumber.int(fromDouble: -9_007_199_254_740_991.0) == -9_007_199_254_740_991)
        // 2^63 超出 Int.max，必须被拒绝。
        #expect(ToolArgumentNumber.int(fromDouble: 9_223_372_036_854_775_808.0) == nil)
    }

    // MARK: - 钳制

    @Test("可表示但超范围的值被钳制")
    func clampsOutOfRangeValues() {
        #expect(ToolArgumentNumber.int(999, clampedTo: 1...50, default: 10) == 50)
        #expect(ToolArgumentNumber.int(0, clampedTo: 1...50, default: 10) == 1)
        #expect(ToolArgumentNumber.int(-3, clampedTo: 1...50, default: 10) == 1)
        #expect(ToolArgumentNumber.int(25, clampedTo: 1...50, default: 10) == 25)
    }

    @Test("无法表示的值退回默认值而不是被当作超大值")
    func unrepresentableValuesFallBackToDefault() {
        // 1e100 是非法输入，不是「合法的超大值」，因此退回默认而不是钳到上界。
        #expect(ToolArgumentNumber.int(1e100, clampedTo: 1...50, default: 10) == 10)
        #expect(ToolArgumentNumber.int(-1e100, clampedTo: 1...50, default: 10) == 10)
    }

    @Test("无法表示的值退回默认值")
    func fallsBackToDefault() {
        #expect(ToolArgumentNumber.int(nil, clampedTo: 1...50, default: 10) == 10)
        #expect(ToolArgumentNumber.int("abc", clampedTo: 1...50, default: 10) == 10)
        #expect(ToolArgumentNumber.int(Double.nan, clampedTo: 1...50, default: 10) == 10)
        #expect(ToolArgumentNumber.int(Double.infinity, clampedTo: 1...50, default: 10) == 10)
    }

    // MARK: - 字典扩展

    @Test("字典扩展读取整型参数")
    func dictionaryExtensionReadsIntegers() {
        let arguments: [String: ToolArgument] = [
            "line": ToolArgument(10),
            "limit": ToolArgument(1e100),
            "name": ToolArgument("x"),
        ]
        #expect(arguments.toolInt("line") == 10)
        // 超范围的值必须返回 nil，而不是崩溃。
        #expect(arguments.toolInt("limit") == nil)
        #expect(arguments.toolInt("name") == nil)
        #expect(arguments.toolInt("missing") == nil)
    }

    @Test("字典扩展读取并钳制整型参数")
    func dictionaryExtensionClampsIntegers() {
        let arguments: [String: ToolArgument] = [
            "count": ToolArgument(1e100),
            "ok": ToolArgument(20),
        ]
        #expect(arguments.toolInt("count", clampedTo: 1...50, default: 10) == 10)
        #expect(arguments.toolInt("ok", clampedTo: 1...50, default: 10) == 20)
        #expect(arguments.toolInt("missing", clampedTo: 1...50, default: 10) == 10)
    }
}
