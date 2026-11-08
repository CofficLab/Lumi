import Foundation
internal import Combine
import KitReminder
import LumiLoggingKit
import OSLog
import UserNotifications
import SwiftUI

/// Hydration Reminder Manager: manages hydration break reminders
@MainActor
class HydrationReminderManager: NSObject, ObservableObject, SuperLog {
    nonisolated static let emoji = "💧"
    /// 详细日志开关。生产环境保持关闭，测试中可临时打开以覆盖日志分支。
    static var verbose: Bool = false

    static let shared = HydrationReminderManager(
        environment: SystemReminderEnvironment { kind in
            guard kind == .hydration else { return }
            HydrationReminderOverlayWindow().showAndFadeOut()
        }
    )

    private let userDefaultsKey = "HydrationReminderInterval"
    private let customIntervalsKey = "HydrationCustomIntervals"
    /// 运行态的持久化键：提醒开启后需跨重启保留。
    private let activeStateKey = "HydrationReminderActive"

    /// 时间 / 持久化 / 计时来源，生产环境为系统实现，测试可注入可控实现。
    private let environment: any ReminderEnvironment

    /// 「今日次数」计数器，状态落在插件专属目录。
    private let dailyCounter: DailyCounter

    @Published private(set) var isActive: Bool = false
    @Published private(set) var selectedInterval: TimeInterval = HydrationReminderManager.defaultInterval.timeInterval
    @Published private(set) var availableIntervals: [IntervalOption] = []
    @Published private(set) var nextBreakTime: Date?
    @Published private(set) var startTime: Date?
    private var timer: ReminderTimerToken?
    /// 今日休息次数。
    ///
    /// 计数与所属日期一起持久化：跨零点后自动归零，重启 App 后仍在。
    /// 状态落在插件专属目录的 Binary Plist（见 `ReminderStateStore`）。
    var todayBreakCount: Int { dailyCounter.todayCount }

    init(environment: any ReminderEnvironment) {
        self.environment = environment
        self.dailyCounter = DailyCounter(
            store: environment.stateStore,
            keyPrefix: "HydrationReminder"
        )
        super.init()

        // Load custom intervals
        loadAvailableIntervals()

        // Load persisted interval
        let savedInterval = environment.savedInterval(forKey: userDefaultsKey)
        if savedInterval > 0 {
            self.selectedInterval = savedInterval
        }

        if Self.verbose {
            os_log("\(self.t)HydrationReminderManager initialized")
        }
    }

    /// 宿主在 `onBoot` 阶段注入插件专属的状态存储目录。
    ///
    /// - Parameter directory: 插件数据目录（`StorageProviding.pluginDataDirectory(for:)`）。
    func attachStateStore(directory: URL) {
        environment.attachStateStore(directory: directory)
        restoreRunningStateIfNeeded()
    }

    /// 若上次退出时提醒处于运行中，则恢复它。
    ///
    /// 用户开启了提醒，重启 App 后提醒应继续工作——否则提醒会**静默停止**，
    /// 用户既看不到提示也无法察觉提醒已经失效。
    private func restoreRunningStateIfNeeded() {
        guard environment.savedActiveState(forKey: activeStateKey) else { return }
        guard !isActive else { return }
        start()
    }

    func start() {
        guard !isActive else { return }
        self.isActive = true
        environment.saveActiveState(true, forKey: activeStateKey)
        self.startTime = environment.now()
        scheduleNextBreak()
    }

    func stop() {
        guard isActive else { return }
        environment.cancel(timer)
        timer = nil
        isActive = false
        environment.saveActiveState(false, forKey: activeStateKey)
        nextBreakTime = nil
        startTime = nil
        // UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func snooze(minutes: Int) {
        guard isActive else { return }
        let interval = TimeInterval(minutes * 60)
        scheduleBreak(in: interval)
    }

    func addCustomInterval(minutes: Int) {
        let option = IntervalOption.minutes(minutes)
        // 按时长（秒）判重：自定义 60 分钟与预设 1 小时是同一时长，
        // 同时存在会让选择器渲染出两个按钮且同时高亮。
        guard !availableIntervals.contains(where: { $0.timeInterval == option.timeInterval }) else {
            return
        }
        availableIntervals.append(option)
        availableIntervals.sort { $0.timeInterval < $1.timeInterval }
        saveCustomIntervals()

        // Auto select the newly added interval
        updateInterval(option.timeInterval)
    }

    func removeInterval(_ option: IntervalOption) {
        // Don't remove default intervals
        guard !Self.commonIntervals.contains(option) else { return }

        availableIntervals.removeAll { $0 == option }
        saveCustomIntervals()

        // If the selected interval no longer exists, fall back to the default.
        if !availableIntervals.contains(where: { $0.timeInterval == selectedInterval }) {
            updateInterval(Self.defaultInterval.timeInterval)
        }
    }

    /// Reset intervals to default
    func resetIntervals() {
        availableIntervals = Self.commonIntervals
        saveCustomIntervals()
        updateInterval(Self.defaultInterval.timeInterval)
    }

    func updateInterval(_ interval: TimeInterval) {
        selectedInterval = interval
        environment.save(interval: interval, forKey: userDefaultsKey)
        if isActive {
            scheduleNextBreak()
        }
    }

    func timeUntilNextBreak() -> TimeInterval? {
        guard let next = nextBreakTime else { return nil }
        return next.timeIntervalSince(environment.now())
    }

    private func scheduleNextBreak() {
        scheduleBreak(in: selectedInterval)
    }

    private func scheduleBreak(in interval: TimeInterval) {
        environment.cancel(timer)
        nextBreakTime = environment.now().addingTimeInterval(interval)
        timer = environment.schedule(after: interval) { [weak self] in
            self?.fireBreakReminder()
        }
    }

    private func fireBreakReminder() {
        guard isActive else { return }
        showDesktopGradient()
        dailyCounter.increment()
        scheduleNextBreak()
    }

    private func showDesktopGradient() {
        environment.presentReminderOverlay(kind: .hydration)
    }

    func cleanup() {
        environment.cancel(timer)
        timer = nil
    }

    private func loadAvailableIntervals() {
        var intervals = Self.commonIntervals

        // Load custom intervals from UserDefaults
        if let customMinutes = environment.savedCustomIntervals(forKey: customIntervalsKey) {
            let customOptions = customMinutes.map { IntervalOption.minutes($0) }
            for option in customOptions {
                if !intervals.contains(option) {
                    intervals.append(option)
                }
            }
        }

        // 按时长（秒）去重：自定义 60 分钟不应与预设 1 小时并存，
        // 否则选择器会渲染出两个按钮且同时高亮。
        intervals = ReminderIntervalList.deduped(intervals) { $0.timeInterval }
        self.availableIntervals = intervals
    }

    private func saveCustomIntervals() {
        let customOptions = availableIntervals.filter { !Self.commonIntervals.contains($0) }
        let customMinutes = customOptions.map { option -> Int in
            switch option {
            case .minutes(let m): return m
            case .hours(let h): return h * 60
            }
        }
        environment.saveCustomIntervals(customMinutes, forKey: customIntervalsKey)
    }
}

extension HydrationReminderManager {
    enum IntervalOption: Hashable, Equatable, Identifiable {
        case minutes(Int)
        case hours(Int)
        var id: String {
            switch self {
            case .minutes(let m): return "m\(m)"
            case .hours(let h): return "h\(h)"
            }
        }
        var displayName: String {
            switch self {
            case .minutes(let m): return String(format: String(localized: "%lld min", table: "HydrationReminder", bundle: .module, comment: "Label for duration in minutes"), m)
            case .hours(let h): return String(format: String(localized: "%lld hr", table: "HydrationReminder", bundle: .module, comment: "Label for duration in hours"), h)
            }
        }
        var timeInterval: TimeInterval {
            switch self {
            case .minutes(let m): return TimeInterval(m * 60)
            case .hours(let h): return TimeInterval(h * 3600)
            }
        }
    }
    static let commonIntervals: [IntervalOption] = [
        .minutes(10),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(3),
    ]

    /// 喝水提醒的默认间隔。
    ///
    /// 首次启动、移除当前选中项、恢复默认时都回退到该值；
    /// 插件描述中的「每 2 小时」也对应它。
    static let defaultInterval: IntervalOption = .hours(2)
}

// extension HydrationReminderManager: UNUserNotificationCenterDelegate {
//    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        completionHandler([.banner, .sound])
//    }
//    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        let actionIdentifier = response.actionIdentifier
//        Task { @MainActor in
//            if actionIdentifier == UNNotificationDefaultActionIdentifier {
//                self.snooze(minutes: 5)
//            }
//        }
//        completionHandler()
//    }
// }
