import Foundation
import IOKit.pwr_mgt
import KitLocalization
import Observation
import ProviderLogo
import ProviderStorage
import KitSuperLog

/// Caffeinate Manager: Responsible for managing system power state
@MainActor
@Observable
final class CaffeinateManager: SuperLog {
    nonisolated static let emoji = "🍽️"
    nonisolated static let verbose: Bool = false

    // MARK: - Singleton

    static let shared = CaffeinateManager()

    // MARK: - Properties

    /// Whether caffeinate is currently active
    private(set) var isActive: Bool = false

    /// Activation start time
    private(set) var startTime: Date?

    /// Preset duration (seconds), 0 means indefinite
    private(set) var duration: TimeInterval = 0

    private(set) var mode: SleepMode = .systemAndDisplay

    /// Whether the current activation was requested with the immediate display-off action.
    private(set) var isDisplayOffRequested = false

    /// 用户在 ViewContainer 配置的「启动时默认模式」。
    ///
    /// 实际生效还需要 Agent 工具 / MenuBar Popup / ViewContainer 在激活时调用
    /// `applyDefaultModeIfNeeded()`，它会读取 LocalStore 并在未激活时按下一次模式。
    private(set) var persistedDefaultMode: SleepMode?

    /// IOKit assertion ID
    private var assertionID: IOPMAssertionID = 0

    private var displayAssertionID: IOPMAssertionID = 0

    /// Timer (used for timed mode)
    private var timer: Timer?

    private weak var storage: (any StorageProviding)?
    private var logo: (any LogoProviding)?

    // MARK: - Initialization

    private init() {
        if Self.verbose {
            CaffeinatePlugin.logger.info("\(self.t)CaffeinateManager initialized")
        }
    }

    func configure(storage: (any StorageProviding)?, logo: (any LogoProviding)?) {
        self.storage = storage
        self.logo = logo
        CaffeinateLocalStore.shared.configure(storage: storage)
        reloadPersistedDefaultMode()
        synchronizeLogoHighlight()
    }

    /// 从 LocalStore 重新加载用户配置的默认模式。
    ///
    /// 在 `configure(kernel:)` 启动时调用一次；用户在 ViewContainer 中修改 Toggle
    /// 时通过 ViewModel 显式触发。
    func reloadPersistedDefaultMode() {
        if let raw = CaffeinateLocalStore.shared.defaultModeRaw,
           let stored = SleepMode(rawValue: raw) {
            persistedDefaultMode = stored
        } else {
            persistedDefaultMode = nil
        }
    }

    /// 写入新的默认启动模式并更新内存中的值。
    ///
    /// - Parameter mode: 要持久化的模式；传 `nil` 表示清除偏好（恢复随用随选）。
    @discardableResult
    func setPersistedDefaultMode(_ mode: SleepMode?) -> Bool {
        let success = CaffeinateLocalStore.shared.setDefaultModeRaw(mode?.rawValue)
        if success {
            persistedDefaultMode = mode
            if Self.verbose {
                CaffeinatePlugin.logger.info("\(self.t)Persisted default mode updated to: \(mode?.rawValue ?? "nil")")
            }
        }
        return success
    }

    private func synchronizeLogoHighlight() {
        guard let logo else {
            CaffeinatePlugin.logger.error("[LogoHighlight] synchronize skipped: logo service is nil")
            return
        }
        guard logo.isLogoHighlighted != isActive else {
            return
        }
        logo.setLogoHighlighted(isActive)
    }

    private func updateLogoHighlight(_ highlighted: Bool) {
        guard let logo else {
            CaffeinatePlugin.logger.error("[LogoHighlight] update skipped: logo service is nil target=\(highlighted)")
            return
        }
        guard logo.isLogoHighlighted != highlighted else {
            return
        }
        logo.setLogoHighlighted(highlighted)
    }

    // MARK: - Public Methods

    /// Activate caffeinate
    /// - Parameter duration: Duration (seconds), 0 means indefinite
    func activate(duration: TimeInterval = 0) {
        activate(mode: .systemAndDisplay, duration: duration)
    }

    /// Activate caffeinate and turn off display immediately
    func activateAndTurnOffDisplay(duration: TimeInterval = 0) {
        // 1. Activate caffeinate (system only, allow display sleep).
        //    如果已在运行，先停掉再以新模式重启，确保 mode 能更新（屏幕常亮 → 允许关闭）
        if isActive {
            deactivate()
        }
        activate(mode: .systemOnly, duration: duration)

        guard isActive else { return }

        // 2. Turn off display
        turnOffDisplay()
        isDisplayOffRequested = true
    }

    private func turnOffDisplay() {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["displaysleepnow"]
        do {
            try task.run()
        } catch {
            if CaffeinatePlugin.verbose {
                CaffeinatePlugin.logger.error("\(self.t)Failed to turn off display: \(error.localizedDescription)")
            }
        }
    }

    func activate(mode: SleepMode, duration: TimeInterval = 0) {
        guard !isActive else {
            if Self.verbose {
                CaffeinatePlugin.logger.info("\(self.t)Caffeinate already active, ignoring activation request")
            }
            return
        }

        self.mode = mode
        isDisplayOffRequested = false
        let reason = "User prevented sleep via Lumi" as NSString

        let systemResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        var displayResult: IOReturn = kIOReturnSuccess
        if mode == .systemAndDisplay {
            displayResult = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
        } else {
            displayAssertionID = 0
        }

        if systemResult == kIOReturnSuccess && displayResult == kIOReturnSuccess {
            isActive = true
            updateLogoHighlight(true)
            startTime = Date()
            self.duration = duration

            if Self.verbose {
                CaffeinatePlugin.logger.info("\(self.t)Caffeinate activated successfully with duration: \(duration)s")
            }

            // Start timer if duration is set
            if duration > 0 {
                startTimer(duration: duration)
            }
        } else {
            if systemResult != kIOReturnSuccess {
                if CaffeinatePlugin.verbose {
                    CaffeinatePlugin.logger.error("\(self.t)Failed to create system sleep assertion: \(systemResult)")
                }
            }
            if displayResult != kIOReturnSuccess {
                if CaffeinatePlugin.verbose {
                    CaffeinatePlugin.logger.error("\(self.t)Failed to create display sleep assertion: \(displayResult)")
                }
            }
            if assertionID != 0 {
                IOPMAssertionRelease(assertionID)
                assertionID = 0
            }
            if displayAssertionID != 0 {
                IOPMAssertionRelease(displayAssertionID)
                displayAssertionID = 0
            }
        }
    }

    /// Deactivate caffeinate
    func deactivate() {
        guard isActive else {
            if Self.verbose {
                CaffeinatePlugin.logger.info("\(self.t)Caffeinate not active, ignoring deactivation request")
            }
            return
        }

        let systemResult = assertionID == 0 ? kIOReturnSuccess : IOPMAssertionRelease(assertionID)
        let displayResult = displayAssertionID == 0 ? kIOReturnSuccess : IOPMAssertionRelease(displayAssertionID)

        if systemResult == kIOReturnSuccess && displayResult == kIOReturnSuccess {
            isActive = false
            isDisplayOffRequested = false
            CaffeinatePlugin.logger.info("[LogoHighlight] caffeinate deactivation succeeded")
            updateLogoHighlight(false)
            startTime = nil
            duration = 0
            assertionID = 0
            displayAssertionID = 0

            // Stop timer
            timer?.invalidate()
            timer = nil

            if Self.verbose {
                CaffeinatePlugin.logger.info("\(self.t)Caffeinate deactivated successfully")
            }
        } else {
            if systemResult != kIOReturnSuccess {
                CaffeinatePlugin.logger.error("\(self.t)Failed to release system sleep assertion: \(systemResult)")
            }
            if displayResult != kIOReturnSuccess {
                CaffeinatePlugin.logger.error("\(self.t)Failed to release display sleep assertion: \(displayResult)")
            }
        }
    }

    /// Toggle caffeinate state
    func toggle() {
        if isActive {
            deactivate()
        } else {
            activate(mode: mode)
        }
    }

    /// Get the duration since activation
    /// - Returns: Time interval since activation (seconds), or nil if not active
    func getActiveDuration() -> TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Private Methods

    /// Start timer
    /// - Parameter duration: Duration (seconds)
    private func startTimer(duration: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if Self.verbose {
                    CaffeinatePlugin.logger.info("\(Self.t)Timer expired, deactivating caffeinate")
                }
                self.deactivate()
            }
        }
        if Self.verbose {
            CaffeinatePlugin.logger.info("\(self.t)Timer scheduled for \(duration)s")
        }
    }

    // MARK: - Cleanup

    deinit {
        // Note: As a @MainActor class, deinit executes on the main thread
        // But deinit cannot access actor-isolated properties
        //
        // Normally, resources should be cleaned up via deactivate()
        // deactivate() already cleaned up:
        //   - IOKit assertions (assertionID, displayAssertionID)
        //   - Timer
        //
        // If the object is released without deactivate,
        // the system will automatically clean up IOKit assertions (when process ends)
        // Timer will also be automatically released
    }
}

// MARK: - Duration Options

extension CaffeinateManager {
    enum SleepMode: String, CaseIterable {
        case systemOnly
        case systemAndDisplay

        var displayName: String {
            switch self {
            case .systemOnly:
                return "Prevent sleep, allow display sleep"
            case .systemAndDisplay:
                return "Prevent sleep, keep display on"
            }
        }
    }

    /// Predefined duration options
    enum DurationOption: Hashable, Equatable {
        case indefinite
        case minutes(Int)
        case hours(Int)

        var displayName: String {
            switch self {
            case .indefinite:
                return LumiPluginLocalization.string("Indefinite", bundle: .module)
            case let .minutes(m):
                return "\(m) \(LumiPluginLocalization.string("Minutes", bundle: .module))"
            case let .hours(h):
                return "\(h) \(LumiPluginLocalization.string("Hours", bundle: .module))"
            }
        }

        var timeInterval: TimeInterval {
            switch self {
            case .indefinite:
                return 0
            case let .minutes(m):
                return TimeInterval(m * 60)
            case let .hours(h):
                return TimeInterval(h * 3600)
            }
        }
    }

    /// Common duration options list
    static let commonDurations: [DurationOption] = [
        .indefinite,
        .minutes(10),
        .minutes(30),
        .hours(1),
        .hours(2),
        .hours(5),
    ]
}
