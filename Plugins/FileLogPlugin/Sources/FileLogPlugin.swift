import LumiCoreKit
import os

/// Collects OSLog entries to rotating on-disk log files.
public enum FileLogPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.file-log",
        displayName: LumiPluginLocalization.string("File Log", bundle: .module),
        description: LumiPluginLocalization.string("Collect OSLog entries to disk files with auto-rotation and cleanup", bundle: .module),
        order: 1,
        category: .system,
        policy: .disabled,
        stage: .beta,
        iconName: "doc.text.below.ecg",
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
            // 从 LumiCore.current 注入 plugin 目录(替代旧的 nonisolated 镜像)。
            // lifecycle 不带 context,但它在 @MainActor 上下文,LumiCore.current 可安全读取。
            // 时序上 current 可能尚未设置(此时 Bridge 保持 nil,走 fallback,与旧镜像行为一致)。
            if let core = LumiCore.current {
                FileLogPluginRuntimeBridge.pluginSubdirectory = core.pluginDataDirectory(for: FileLogPluginRuntimeBridge.pluginName)
            }
            bootstrapIfNeeded()
        case .projectDidOpen, .projectDidClose:
            break
        case .willDisable:
            // FileLogPlugin 是 alwaysOn，不会被禁用；此事件无需处理。
            break
        }
    }
}
