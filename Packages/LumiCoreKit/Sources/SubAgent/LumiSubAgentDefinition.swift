import Foundation

/// 子 Agent 的声明式定义。
///
/// 由插件在 `LumiPlugin.subAgents(context:)` 中返回，内核聚合后
/// 自动包装成 `delegate_<id>` 工具，注入 toolService。
///
/// ## 工具过滤
///
/// 子 Agent 能使用哪些工具，由 `requiredTags` / `excludedTags` / `additionalToolNames`
/// / `excludedToolNames` 四维过滤：
///
/// ```
/// 全集 = toolService.tools
///   1. 按 requiredTags 过滤（OR 语义：包含任一标签即保留）
///   2. 移除 excludedTags（包含任一排除标签即移除）
///   3. 移除 excludedToolNames（精确排除）
///   4. 加上 additionalToolNames（去重补充）
/// ```
///
/// ## 示例
///
/// ```swift
/// LumiSubAgentDefinition(
///     id: "git-commit-writer",
///     providerID: "stepfun",
///     modelID: "step-3.7-flash",
///     requiredTags: [.git],
///     excludedTags: [.destructive],
///     excludedToolNames: ["git_push"],
///     systemPrompt: "你是 Git 提交助手..."
/// )
/// ```
public struct LumiSubAgentDefinition: Sendable, Identifiable {
    // MARK: - 标识

    /// 全局唯一标识，如 "git-commit-writer"。
    /// 工具名会变成 "delegate_git-commit-writer"。
    public let id: String

    /// 显示名称，用于 UI / 日志
    public let displayName: String

    /// 暴露给主 LLM 的工具描述（告诉主 Agent 何时该调用这个子 Agent）
    public let description: String

    // MARK: - 模型绑定

    /// 绑定的 LLM provider id（如 "stepfun"）。子 Agent 用这个 provider 推理。
    public let providerID: String

    /// 绑定的模型 id（如 "step-3.7-flash"）。
    /// 由该 provider 自己决定最合适的模型。
    public let modelID: String

    // MARK: - 行为

    /// 子 Agent 的 system prompt，引导其行为。
    public let systemPrompt: String

    // MARK: - 工具过滤

    /// 必须包含的标签（OR 语义）。
    /// 运行时从 `toolService.tools` 中筛选**包含任一标签的工具**。
    ///
    /// - 空集 = 不过滤（结合 `excludedTags` 单独使用）
    /// - `{.all}` = 全部工具
    /// - `{.git, .readOnly}` = 包含 git 标签 **或** readOnly 标签的工具
    public let requiredTags: Set<LumiToolTag>

    /// 排除的标签。包含任一标签的工具被移除。
    /// 例如 `{.destructive}` 表示子 Agent 不能用任何破坏性工具。
    public let excludedTags: Set<LumiToolTag>

    /// 显式包含的额外工具名（标签过滤的补充）。
    /// 用于「按标签过滤 + 想加某个特定工具」的场景。
    public let additionalToolNames: Set<String>

    /// 显式排除的工具名（精细排除，标签之外的兜底）。
    /// 用于「标签规则有遗漏时精确排除某个工具」。
    public let excludedToolNames: Set<String>

    // MARK: - 约束

    /// 最大推理轮数，防失控。默认 10。
    public let maxTurns: Int

    /// 可选图标名（SF Symbol 名称）
    public let iconName: String?

    // MARK: - Init

    public init(
        id: String,
        displayName: String,
        description: String,
        providerID: String,
        modelID: String,
        systemPrompt: String,
        requiredTags: Set<LumiToolTag> = [],
        excludedTags: Set<LumiToolTag> = [],
        additionalToolNames: Set<String> = [],
        excludedToolNames: Set<String> = [],
        maxTurns: Int = 10,
        iconName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.providerID = providerID
        self.modelID = modelID
        self.systemPrompt = systemPrompt
        self.requiredTags = requiredTags
        self.excludedTags = excludedTags
        self.additionalToolNames = additionalToolNames
        self.excludedToolNames = excludedToolNames
        self.maxTurns = maxTurns
        self.iconName = iconName
    }
}
