import Foundation
import Testing
@testable import KitReminder

/// 提醒插件的间隔列表去重行为。
///
/// 去重键是**时长（秒）**而非枚举 case，因为选择器的高亮判定
/// 是 `selectedInterval == option.timeInterval`（按秒比较）。
/// 若按 case 去重，自定义 60 分钟与预设 1 小时会同时存在，
/// 用户会看到两个按钮且两个同时高亮。
@Suite("ReminderIntervalList 去重")
struct ReminderIntervalListTests {
    /// 极简的测试用选项：只关心时长。
    private struct Option: Equatable {
        let name: String
        let seconds: TimeInterval
    }

    @Test("相同时长的选项只保留最先出现的一个")
    func keepsFirstOfSameDuration() {
        let result = ReminderIntervalList.deduped(
            [Option(name: "1h", seconds: 3600), Option(name: "60min", seconds: 3600)]
        ) { $0.seconds }

        #expect(result.count == 1)
        #expect(result.first?.name == "1h")
    }

    @Test("不同时长的选项全部保留")
    func keepsDistinctDurations() {
        let result = ReminderIntervalList.deduped(
            [Option(name: "10min", seconds: 600), Option(name: "1h", seconds: 3600)]
        ) { $0.seconds }

        #expect(result.count == 2)
    }

    @Test("结果按时长升序排列")
    func sortsAscending() {
        let result = ReminderIntervalList.deduped(
            [
                Option(name: "3h", seconds: 10800),
                Option(name: "10min", seconds: 600),
                Option(name: "1h", seconds: 3600),
            ]
        ) { $0.seconds }

        #expect(result.map(\.seconds) == [600, 3600, 10800])
    }

    @Test("去重后时长互不相同")
    func resultHasNoDuplicateDurations() {
        let result = ReminderIntervalList.deduped(
            [
                Option(name: "10min", seconds: 600),
                Option(name: "60min", seconds: 3600),
                Option(name: "1h", seconds: 3600),
                Option(name: "120min", seconds: 7200),
                Option(name: "2h", seconds: 7200),
            ]
        ) { $0.seconds }

        #expect(result.map(\.seconds) == [600, 3600, 7200])
    }

    @Test("空输入返回空结果")
    func emptyInput() {
        let result = ReminderIntervalList.deduped([Option]()) { $0.seconds }
        #expect(result.isEmpty)
    }
}
