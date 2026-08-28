import ProviderProject

/// AgentRules 插件的运行时持有（KernelCore 体系）。
///
/// 由旧版 `kernel.currentProjectPath` / `kernel.project` 依赖迁移而来：
/// 主插件在 `onBoot` 解析内核的 `ProjectProviding` 并持有，工具与设置视图读取。
@MainActor
public enum AgentRulesRuntime {
    public private(set) static var project: (any ProjectProviding)?

    public static func configure(project: (any ProjectProviding)?) {
        self.project = project
    }

    public static func reset() {
        project = nil
    }

    /// 当前项目路径（沿用旧版 `kernel.currentProjectPath` 语义）。
    public static var currentProjectPath: String? {
        project?.currentProject?.path
    }
}
