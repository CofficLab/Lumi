import Foundation
import Testing
@testable import GitPlugin

/// `git_log` 的 count 参数必须先检查范围再转换。
///
/// JSON 数字会桥接成 `Double`，而 `Int(_:)` 对超出 `Int` 范围的 `Double`
/// 会触发 Swift 运行时陷阱（precondition failure），直接终止宿主进程。
@Suite("GitLogTool count 参数")
struct GitLogToolCountTests {

    @Test("超大 Double 退回默认值而不是崩溃")
    func oversizedDoubleFallsBackToDefault() {
        // 旧实现：`Int(1e100)` 直接 trap。
        #expect(GitLogTool.normalizedCount(1e100 as Any) == 10)
        #expect(GitLogTool.normalizedCount(-1e100 as Any) == 10)
    }

    @Test("非有限值退回默认值")
    func nonFiniteFallsBackToDefault() {
        #expect(GitLogTool.normalizedCount(Double.infinity as Any) == 10)
        #expect(GitLogTool.normalizedCount(Double.nan as Any) == 10)
    }

    @Test("可表示但超范围的值被钳制")
    func representableOutOfRangeIsClamped() {
        #expect(GitLogTool.normalizedCount(999 as Any) == 50)
        #expect(GitLogTool.normalizedCount(0 as Any) == 1)
        #expect(GitLogTool.normalizedCount(-5 as Any) == 1)
    }

    @Test("范围内的值原样保留")
    func inRangeIsKept() {
        #expect(GitLogTool.normalizedCount(25 as Any) == 25)
        #expect(GitLogTool.normalizedCount(1 as Any) == 1)
        #expect(GitLogTool.normalizedCount(50 as Any) == 50)
        #expect(GitLogTool.normalizedCount(25.0 as Any) == 25)
        #expect(GitLogTool.normalizedCount("30" as Any) == 30)
    }

    @Test("缺失或非法值使用默认值")
    func missingOrInvalidUsesDefault() {
        #expect(GitLogTool.normalizedCount(nil) == 10)
        #expect(GitLogTool.normalizedCount("abc" as Any) == 10)
        #expect(GitLogTool.normalizedCount([1, 2] as Any) == 10)
    }
}
