import Foundation
import ProviderProject

/// AgentRules 插件的运行时持有（KernelCore 体系）。
///
/// 由旧版 `kernel.currentProjectPath` / `kernel.project` 依赖迁移而来：
/// 主插件在 `onBoot` 解析内核的 `ProjectProviding` 并持有，工具与设置视图读取。
@MainActor
public enum AgentRulesRuntime {
    public private(set) static var project: (any ProjectProviding)?

    /// 插件配置目录。由主插件在 `onBoot` 中从 `StorageProviding` 注入。
    ///
    /// 存根回退路径仅用于插件尚未 boot 的极早期访问（如预览、测试），
    /// 形状与内核 `StorageProviding` 的版本化数据根保持一致。
    public nonisolated(unsafe) static var settingsDirectoryProvider: () -> URL = {
        fallbackSettingsDirectory
    }

    public nonisolated static func settingsDirectory() -> URL {
        settingsDirectoryProvider()
    }

    public nonisolated static func configure(settingsDirectory: URL) {
        settingsDirectoryProvider = { settingsDirectory }
    }

    private nonisolated static let fallbackSettingsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #if DEBUG
        let versionedRoot = "db_debug_v6"
        #else
        let versionedRoot = "db_production_v6"
        #endif
        return base
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent(versionedRoot, isDirectory: true)
            .appendingPathComponent("com.coffic.lumi.plugin.agent-rules", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }()

    public static func configure(project: (any ProjectProviding)?) {
        self.project = project
    }

    public static func reset() {
        project = nil
        settingsDirectoryProvider = { fallbackSettingsDirectory }
    }

    /// 当前项目路径（沿用旧版 `kernel.currentProjectPath` 语义）。
    public static var currentProjectPath: String? {
        project?.currentProject?.path
    }
}
