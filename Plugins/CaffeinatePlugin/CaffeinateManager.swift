import Foundation
import IOKit.pwr_mgt
import Observation
import OSLog

/// 防休眠管理器：负责管理系统电源状态
@Observable
class CaffeinateManager {
    // MARK: - Singleton

    static let shared = CaffeinateManager()

    // MARK: - Properties

    /// 当前是否激活防休眠
    private(set) var isActive: Bool = false

    /// 激活开始时间
    private(set) var startTime: Date?

    /// 预设持续时间（秒），0 表示永久
    private(set) var duration: TimeInterval = 0

    /// IOKit 断言 ID
    private var assertionID: IOPMAssertionID = 0

    private var displayAssertionID: IOPMAssertionID = 0

    /// 定时器（用于定时模式）
    private var timer: Timer?

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "CaffeinateManager")

    // MARK: - Initialization

    private init() {
        logger.info("CaffeinateManager initialized")
    }

    // MARK: - Public Methods

    /// 激活防休眠
    /// - Parameter duration: 持续时间（秒），0 表示永久
    func activate(duration: TimeInterval = 0) {
        guard !isActive else {
            logger.info("Caffeinate already active, ignoring activation request")
            return
        }

        let reason = "User prevented sleep via Lumi" as NSString

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayAssertionID
        )

        if systemResult == kIOReturnSuccess && displayResult == kIOReturnSuccess {
            isActive = true
            startTime = Date()
            self.duration = duration

            logger.info("Caffeinate activated successfully with duration: \(duration)s")

            // 如果设置了定时，启动定时器
            if duration > 0 {
                startTimer(duration: duration)
            }
        } else {
            if systemResult != kIOReturnSuccess {
                logger.error("Failed to create system sleep assertion: \(systemResult)")
            }
            if displayResult != kIOReturnSuccess {
                logger.error("Failed to create display sleep assertion: \(displayResult)")
            }
        }
    }

    /// 停用防休眠
    func deactivate() {
        guard isActive else {
            logger.info("Caffeinate not active, ignoring deactivation request")
            return
        }

        let systemResult = IOPMAssertionRelease(assertionID)
        let displayResult = IOPMAssertionRelease(displayAssertionID)

        if systemResult == kIOReturnSuccess && displayResult == kIOReturnSuccess {
            isActive = false
            startTime = nil
            duration = 0
            assertionID = 0
            displayAssertionID = 0

            // 停止定时器
            timer?.invalidate()
            timer = nil

            logger.info("Caffeinate deactivated successfully")
        } else {
            if systemResult != kIOReturnSuccess {
                logger.error("Failed to release system sleep assertion: \(systemResult)")
            }
            if displayResult != kIOReturnSuccess {
                logger.error("Failed to release display sleep assertion: \(displayResult)")
            }
        }
    }

    /// 切换防休眠状态
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    /// 获取已激活的持续时间
    /// - Returns: 激活至今的时间间隔（秒），如果未激活则返回 nil
    func getActiveDuration() -> TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Private Methods

    /// 启动定时器
    /// - Parameter duration: 持续时间（秒）
    private func startTimer(duration: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.logger.info("Timer expired, deactivating caffeinate")
            self?.deactivate()
        }
        logger.info("Timer scheduled for \(duration)s")
    }

    // MARK: - Cleanup

    deinit {
        // 清理资源
        if isActive {
            IOPMAssertionRelease(assertionID)
            IOPMAssertionRelease(displayAssertionID)
        }
        timer?.invalidate()
    }
}

// MARK: - Duration Options

extension CaffeinateManager {
    /// 预设的时间选项
    enum DurationOption: Hashable, Equatable {
        case indefinite
        case minutes(Int)
        case hours(Int)

        var displayName: String {
            switch self {
            case .indefinite:
                return "永久"
            case .minutes(let m):
                return "\(m) 分钟"
            case .hours(let h):
                return "\(h) 小时"
            }
        }

        var timeInterval: TimeInterval {
            switch self {
            case .indefinite:
                return 0
            case .minutes(let m):
                return TimeInterval(m * 60)
            case .hours(let h):
                return TimeInterval(h * 3600)
            }
        }

        var icon: String {
            switch self {
            case .indefinite:
                return "∞"
            case .minutes:
                return "🕐"
            case .hours:
                return "📅"
            }
        }
    }

    /// 常用的时间选项列表
    static let commonDurations: [DurationOption] = [
        .indefinite,
        .minutes(10),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(5)
    ]
}
