import Foundation
import KitTestIsolation
import ProviderProject

/// AgentRules 插件的运行时持有（KernelCore 体系）。
///
/// 由旧版 `kernel.currentProjectPath` / `kernel.project` 依赖迁移而来：
/// 主插件在 `onBoot` 解析内核的 `ProjectProviding` 并持有，工具与设置视图读取。
@MainActor
public enum AgentRulesRuntime {
    public private(set) static var project: (any ProjectProviding)?

    /// `onBoot` 注入的插件配置目录。未注入时为 `nil`。
    ///
    /// 测试进程下未注入即失败，杜绝静默写入本机真实数据目录
    /// （见 `IsolatedDirectoryGuard`）。
    public nonisolated(unsafe) static var injectedSettingsDirectory: URL?

    public nonisolated static func settingsDirectory() -> URL {
        IsolatedDirectoryGuard.directory(
            injected: injectedSettingsDirectory,
            owner: "AgentRulesRuntime",
            accessor: "settingsDirectory()",
            fallback: { productionFallbackSettingsDirectory }
        )
    }

    public nonisolated static func configure(settingsDirectory: URL) {
        injectedSettingsDirectory = settingsDirectory
    }

    /// 生产环境兜底目录，形状与内核 `StorageProviding` 的版本化数据根保持一致。
    private nonisolated static let productionFallbackSettingsDirectory: URL = {
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
        injectedSettingsDirectory = nil
    }

    /// 当前项目路径（沿用旧版 `kernel.currentProjectPath` 语义）。
    public static var currentProjectPath: String? {
        project?.currentProject?.path
    }
}
