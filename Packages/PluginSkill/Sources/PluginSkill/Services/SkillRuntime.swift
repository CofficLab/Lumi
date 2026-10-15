import ProviderProject

/// Skill 插件的运行时持有（KernelCore 体系）。
///
/// 与 `AgentRulesRuntime` 同构：主插件在 `onBoot` 解析内核 `ProjectProviding`
/// 并持有，工具通过它回退到「当前项目」，避免工具直接依赖内核。
@MainActor
public enum SkillRuntime {
    public private(set) static var project: (any ProjectProviding)?

    public static func configure(project: (any ProjectProviding)?) {
        self.project = project
    }

    public static func reset() {
        project = nil
    }

    /// 当前项目路径（工具未显式传 `project_path` 时的回退来源）。
    public static var currentProjectPath: String? {
        project?.currentProject?.path
    }
}
