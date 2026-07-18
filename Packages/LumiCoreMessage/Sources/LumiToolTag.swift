import Foundation

/// 工具标签。用于子 Agent 按能力/风险/特性维度过滤工具。
///
/// ## 设计原则
///
/// - **叠加语义**：一个工具可有多个标签（非互斥分类）。例如 `GitStatusTool`
///   同时声明 `[.git, .readOnly, .fast]`，表达「既是 git 工具、又是只读工具、
///   又是快速工具」。
/// - **特征而非归属**：标签描述工具的「特征」，不描述它的「分组」。分类（如
///   「git 类」「fs 类」）是排他的；标签是叠加的。
/// - **可扩展**：内核预定义常用标签，但插件可用 `LumiToolTag("pluginID.tagName")`
///   自由扩展自定义标签，无需改内核。
///
/// ## 典型用法
///
/// 工具实现声明 tags：
///
/// ```swift
/// public struct GitStatusTool: LumiAgentTool {
///     public static let tags: Set<LumiToolTag> = [.git, .readOnly, .fast]
///     // ...
/// }
/// ```
///
/// 子 Agent 定义按标签过滤：
///
/// ```swift
/// LumiSubAgentDefinition(
///     id: "git-commit-writer",
///     requiredTags: [.git],
///     excludedTags: [.destructive],
///     // ...
/// )
/// ```
public struct LumiToolTag: Hashable, Sendable, Codable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ name: String) {
        self.init(rawValue: name)
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension LumiToolTag {
    // MARK: - 能力领域标签

    /// 文件系统读写（read_file / write_file / edit_file）
    public static let fileSystem = LumiToolTag("file_system")

    /// Git 操作（git_status / git_diff / git_add / git_commit / ...）
    public static let git = LumiToolTag("git")

    /// Shell 命令执行
    public static let shell = LumiToolTag("shell")

    /// 网络请求 / HTTP / 浏览器
    public static let network = LumiToolTag("network")

    /// 代码搜索 / LSP / 编辑器能力
    public static let codeIntelligence = LumiToolTag("code_intelligence")

    /// App Store Connect / 部署相关
    public static let deployment = LumiToolTag("deployment")

    /// 记忆 / 知识库
    public static let memory = LumiToolTag("memory")

    /// 用户交互（AskUser / 审批）
    public static let userInteraction = LumiToolTag("user_interaction")

    // MARK: - 风险特征标签

    /// 只读工具：不修改任何状态
    public static let readOnly = LumiToolTag("read_only")

    /// 破坏性操作：删除、覆盖、强制推送
    public static let destructive = LumiToolTag("destructive")

    /// 需要审批的操作
    public static let requiresApproval = LumiToolTag("requires_approval")

    /// 可能产生外部副作用（发邮件、发推、付费 API）
    public static let sideEffect = LumiToolTag("side_effect")

    // MARK: - 性能特征标签

    /// 快速响应（< 1s）
    public static let fast = LumiToolTag("fast")

    /// 慢速操作（> 5s，可能需要流式）
    public static let slow = LumiToolTag("slow")

    /// 大输出（可能消耗大量上下文）
    public static let largeOutput = LumiToolTag("large_output")

    // MARK: - 特殊标签

    /// 通配：所有工具（用于子 Agent 声明「全部工具」）
    public static let all = LumiToolTag("*")
}

extension LumiToolTag: CustomStringConvertible {
    public var description: String { rawValue }
}