import Foundation

/// 提醒弹层类型，用于区分护眼 / 喝水 / 拉伸三种语义。
public enum ReminderOverlayKind: String, Sendable {
    case eyeCare
    case hydration
    case stretch
}

/// 计时器句柄，用于取消尚未触发的回调。
public struct ReminderTimerToken: Hashable, Sendable {
    public let id: UInt64

    public init(id: UInt64) {
        self.id = id
    }
}

/// 抽象「休息提醒」所需的时间、持久化、计时与弹窗能力。
///
/// 三个 Reminder 插件（护眼 / 喝水 / 拉伸）原本直接依赖
/// `Date()`、`UserDefaults.standard`、`Timer.scheduledTimer`
/// 与真实的 NSWindow 弹层，导致 `start` / `stop` / `snooze` /
/// 间隔持久化这些真正会出错的逻辑无法在测试进程中验证
/// （单例 + 硬编码系统依赖 + 无窗口环境）。
///
/// 抽出该协议后，生产环境仍由 `SystemReminderEnvironment` 提供真实实现，
/// 行为完全不变；测试可注入可控实现精确推进时间与触发回调。
@MainActor
public protocol ReminderEnvironment: AnyObject {
    /// 当前时间
    func now() -> Date

    /// 读取已持久化的选中间隔（秒）；无记录时返回 0
    func savedInterval(forKey key: String) -> TimeInterval

    /// 写入选中间隔（秒）
    func save(interval: TimeInterval, forKey key: String)

    /// 读取已持久化的自定义间隔（分钟）
    func savedCustomIntervals(forKey key: String) -> [Int]?

    /// 写入自定义间隔（分钟）
    func saveCustomIntervals(_ minutes: [Int], forKey key: String)

    /// 读取已持久化的「运行中」状态。
    ///
    /// 提醒的运行态需要跨重启保留：用户开启了护眼提醒，重启 App 后
    /// 提醒应继续工作，而不是静默停止。
    /// 键不存在时返回 false（首次启动即为未运行）。
    func savedActiveState(forKey key: String) -> Bool

    /// 写入「运行中」状态。
    func saveActiveState(_ isActive: Bool, forKey key: String)

    /// 在指定延迟后触发回调；返回的 token 用于取消
    func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> ReminderTimerToken

    /// 取消尚未触发的计时
    func cancel(_ token: ReminderTimerToken?)

    /// 展示休息提醒弹层。生产环境创建真实覆盖窗口；
    /// 测试中可替换为仅计数的实现，避免无窗口进程崩溃。
    func presentReminderOverlay(kind: ReminderOverlayKind)

    /// 系统从睡眠中唤醒时调用。
    ///
    /// `Timer` 在睡眠期间不会触发，醒来后若原本的到期时间已过，
    /// 应当立即补触发，而不是静默推迟到下一个间隔。
    /// 实现可自行判断是否有到期项；默认实现为空操作（测试环境无需响应）。
    func didWakeFromSleep()

    /// 插件状态存储。
    ///
    /// 按 CofficLab 兄弟项目的存储规范，插件状态落盘在宿主分配的
    /// 插件专属目录（Binary Plist），而不是 `UserDefaults.standard`。
    ///
    /// 宿主在 `onBoot(kernel:)` 解析出 `StorageProviding` 后注入；
    /// 未注入时（测试环境）可退回到内存存储。
    var stateStore: ReminderStateStore { get set }

    /// 宿主在 `onBoot` 阶段注入插件专属的状态存储目录。
    ///
    /// - Parameter directory: 插件数据目录（`StorageProviding.pluginDataDirectory(for:)`）。
    func attachStateStore(directory: URL)
}

public extension ReminderEnvironment {
    func attachStateStore(directory: URL) {
        stateStore = ReminderStateStore(directory: directory)
    }

    /// 默认实现为空操作：测试环境不需要响应系统唤醒。
    func didWakeFromSleep() {}
}

/// 生产环境实现：直接使用系统 API，行为与抽象前一致。
///
/// 弹层窗口的具体类型由各插件自行决定，本实现只负责时间、
/// 持久化与计时；`overlayPresenter` 由插件在初始化时注入。
@MainActor
public final class SystemReminderEnvironment: ReminderEnvironment {
    public static let shared = SystemReminderEnvironment()

    /// 各插件注入自己的弹层构造函数（接收 nil 表示无需展示）。
    private let overlayPresenter: @MainActor (ReminderOverlayKind) -> Void

    /// 插件状态存储；宿主注入目录后即落盘到插件专属目录。
    public var stateStore: ReminderStateStore

    private var nextToken: UInt64 = 0
    private var timers: [UInt64: ScheduledTimer] = [:]

    public init(
        overlayPresenter: @escaping @MainActor (ReminderOverlayKind) -> Void = { _ in },
        stateStore: ReminderStateStore = .inMemory()
    ) {
        self.overlayPresenter = overlayPresenter
        self.stateStore = stateStore
        // 订阅系统唤醒：睡眠期间到期的提醒在醒来后立即补触发。
        wakeSubscription = SystemWakeObserver.shared.subscribe { [weak self] in
            self?.didWakeFromSleep()
        }
    }

    /// 系统唤醒订阅标识。
    private var wakeSubscription: UUID?

    /// 由宿主在 `onBoot` 阶段注入插件专属的状态存储目录。
    ///
    /// - Parameter directory: 插件数据目录（`StorageProviding.pluginDataDirectory(for:)`）。
    public func attachStateStore(directory: URL) {
        stateStore = ReminderStateStore(directory: directory)
    }

    public func now() -> Date { Date() }

    public func savedInterval(forKey key: String) -> TimeInterval {
        UserDefaults.standard.double(forKey: key)
    }

    public func save(interval: TimeInterval, forKey key: String) {
        UserDefaults.standard.set(interval, forKey: key)
    }

    public func savedCustomIntervals(forKey key: String) -> [Int]? {
        UserDefaults.standard.array(forKey: key) as? [Int]
    }

    public func saveCustomIntervals(_ minutes: [Int], forKey key: String) {
        UserDefaults.standard.set(minutes, forKey: key)
    }

    public func savedActiveState(forKey key: String) -> Bool {
        stateStore.bool(forKey: key) ?? false
    }

    public func saveActiveState(_ isActive: Bool, forKey key: String) {
        stateStore.setBool(isActive, forKey: key)
    }

    public func schedule(after delay: TimeInterval, handler: @escaping () -> Void) -> ReminderTimerToken {
        nextToken += 1
        let token = ReminderTimerToken(id: nextToken)
        let deadline = Date().addingTimeInterval(delay)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.timers[token.id] = nil
            handler()
        }
        // 装入 `.common` 模式而非默认的 `.default`：
        // AppKit 事件跟踪期间（拖菜单、滑块、缩放窗口）default 模式的 timer
        // 不触发，提醒会被推迟到交互结束——而界面上的倒计时早已归零。
        RunLoop.main.add(timer, forMode: .common)
        timers[token.id] = ScheduledTimer(timer: timer, deadline: deadline, handler: handler)
        return token
    }

    public func cancel(_ token: ReminderTimerToken?) {
        guard let token else { return }
        timers[token.id]?.timer.invalidate()
        timers[token.id] = nil
    }

    public func presentReminderOverlay(kind: ReminderOverlayKind) {
        overlayPresenter(kind)
    }

    /// 响应系统唤醒：把睡眠期间已到期的计时立即触发。
    ///
    /// `Timer` 在系统睡眠期间不推进，醒来后原本到期的提醒会被静默推迟
    /// （甚至直到下一个间隔才补上）。这里记录每个计时的**绝对到期时间**，
    /// 醒来时检查哪些已过期并立即触发回调。
    public func didWakeFromSleep() {
        let now = Date()
        let expired = Self.expiredTimerIDs(in: timers, now: now)

        for id in expired {
            // 先取出条目再移除：移除后 handlers 就取不到了。
            guard let entry = timers.removeValue(forKey: id) else { continue }
            entry.timer.invalidate()
            entry.handler()
        }
    }

    /// 找出已到期的计时（纯逻辑，便于测试）。
    ///
    /// - Parameters:
    ///   - timers: 当前排定的计时。
    ///   - now: 当前时间。
    /// - Returns: 已到期的计时 id（升序）。
    static func expiredTimerIDs(
        in timers: [UInt64: ScheduledTimer],
        now: Date
    ) -> [UInt64] {
        timers.filter { $0.value.deadline <= now }.keys.sorted()
    }

    /// 把某个计时的到期时间改到过去（测试辅助）。
    ///
    /// 真实场景中这由「系统睡眠期间时间流逝」自然造成；
    /// 测试里显式改写，避免真的等待。
    func markTimerExpired(_ token: ReminderTimerToken) {
        guard var entry = timers[token.id] else { return }
        timers[token.id] = ScheduledTimer(
            timer: entry.timer,
            deadline: Date().addingTimeInterval(-1),
            handler: entry.handler
        )
    }

    /// 记录一个计时及其绝对到期时间。
    struct ScheduledTimer {
        let timer: Timer
        let deadline: Date
        let handler: () -> Void
    }
}
