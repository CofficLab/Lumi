import LumiCoreKit
import os

/// Collects OSLog entries to rotating on-disk log files.
public enum FileLogPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "doc.text.below.ecg"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.file-log",
        displayName: LumiPluginLocalization.string("File Log", bundle: .module),
        description: LumiPluginLocalization.string("Collect OSLog entries to disk files with auto-rotation and cleanup", bundle: .module),
        order: 1
    )

    nonisolated(unsafe) public static var configuration: FileLogConfiguration = DefaultFileLogConfiguration()

    public static func bootstrapIfNeeded() {
        FileLogCoordinator.shared.start()
    }

    // MARK: - LumiPlugin Lifecycle

    /// 在应用启动生命周期事件中启动 OSLog 轮询。
    ///
    /// 同时响应 `.didRegister` 和 `.appDidLaunch` 作为防御性兜底：
    /// 只要 `LumiPluginRegistry` 在任一阶段调用了 `lifecycle(...)`，
    /// Coordinator 就会被启动。宿主无需感知本插件存在。
    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister, .appDidLaunch:
            bootstrapIfNeeded()
        case .projectDidOpen, .projectDidClose:
            break
        case .willDisable:
            // FileLogPlugin 是 alwaysOn，不会被禁用；此事件无需处理。
            break
        }
    }
}
