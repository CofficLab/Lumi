import Foundation
import KitSuperLog
import os

// MARK: - Skill 元数据

/// Skill 元数据模型（与旧版 `.agent/skills/` 目录规则一致）。
///
/// 一个 Skill 由元数据 + 正文（SKILL.md）构成。插件贡献的技能通常只提供
/// 元数据 + 内容字符串；文件系统来源的技能通过 `contentPath` 指向 SKILL.md。
public struct SkillMetadata: Identifiable, Equatable, Sendable, Codable {
    /// 唯一标识，默认等于 `name`。
    public let id: String
    /// 技能名（kebab-case，如 `xcode-build`）。
    public let name: String
    /// 展示标题。
    public let title: String
    /// 一句话描述，注入 system prompt 时使用。
    public let description: String
    /// 触发词（供 LLM 判断何时应用该技能）。
    public let triggers: [String]
    /// 版本号。
    public let version: String
    /// 正文文件路径（文件系统来源）；插件贡献时可为空，直接携带 `content`。
    public let contentPath: String
    /// 正文内容（插件贡献时优先使用；为空时回退读取 `contentPath`）。
    public let content: String?
    /// 最后修改时间（排序 / 诊断用）。
    public let modifiedAt: Date

    public init(
        id: String? = nil,
        name: String,
        title: String,
        description: String,
        triggers: [String] = [],
        version: String = "1.0.0",
        contentPath: String = "",
        content: String? = nil,
        modifiedAt: Date = Date()
    ) {
        self.id = id ?? name
        self.name = name
        self.title = title
        self.description = description
        self.triggers = triggers
        self.version = version
        self.contentPath = contentPath
        self.content = content
        self.modifiedAt = modifiedAt
    }

    /// 按 name 判等的便捷方法（去重语义：同名视为同一技能）。
    public func hasSameName(_ other: SkillMetadata) -> Bool {
        name == other.name
    }

    /// 加载技能正文：优先使用内嵌 `content`，为空时回退读取 `contentPath`。
    ///
    /// 插件贡献的技能通常直接携带 `content`；文件系统来源的技能
    /// （项目 `.agent/skills/`、内置资源目录）依赖 `contentPath` 指向的
    /// `SKILL.md`。两种来源都能通过本方法拿到统一的正文文本。
    public func loadContent() -> String? {
        if let content, !content.isEmpty {
            return content
        }
        guard !contentPath.isEmpty else { return nil }
        return try? String(contentsOfFile: contentPath, encoding: .utf8)
    }
}

extension SkillMetadata {
    /// 兼容旧版 `Codable` 行为：`id` 从 `name` 派生，`content` / `contentPath`
    /// 不在元数据 JSON 中编解码。
    private enum CodingKeys: String, CodingKey {
        case name, title, description, triggers, version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        triggers = try container.decodeIfPresent([String].self, forKey: .triggers) ?? []
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0.0"
        id = name
        contentPath = ""
        content = nil
        modifiedAt = Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(triggers, forKey: .triggers)
        try container.encode(version, forKey: .version)
    }
}

// MARK: - Skill 贡献契约

/// 插件贡献 Skill 的数据源契约。
///
/// 每个想贡献 Skill 的插件在 `onBoot` 中从内核解析 `SkillProviding`，
/// 然后用自身实现（通常是结构体的 `allSkills` 属性）调用 `addProvider(_:)`
/// 注入。协议刻意轻量、`Sendable`，允许纯值类型实现：
///
/// ```swift
/// struct XcodeBuildSkillContributor: SkillContributing {
///     var providerID: String { "com.coffic.lumi.plugin.xcode-build" }
///     var allSkills: [SkillMetadata] { [.init(name: "xcode-build", ...)] }
/// }
/// ```
///
/// 与 `ToolManagerProviding` 的 `add(_:pluginID:)`、`LLMManaging` 的
/// 供应商注册属于同一「插件向 Provider 注册贡献」模式。
public protocol SkillContributing: Sendable {
    /// 贡献方唯一标识（通常为插件 ID）。
    var providerID: String { get }

    /// 贡献方提供的全部技能。
    var allSkills: [SkillMetadata] { get }
}

// MARK: - Skill 管理协议

/// Skill 管理能力协议：插件在 `onBoot` 从内核解析本 Provider，注入自己的技能。
///
/// 职责：
/// - 维护各 `SkillContributing` 贡献者（插件）的注册表；
/// - 提供聚合查询：`allSkills()` 返回全部贡献技能；
/// - 幂等撤销：插件 `onShutdown` 时调用 `removeProvider(providerID:)`。
///
/// 与 `ToolManagerProviding`（`add(_:pluginID:)` / `remove(id:)`）、
/// `LLMManaging`（供应商注册表）同构：Provider 只维护注册表，
/// 消费方（如 `PluginSkill`）读取聚合结果注入 LLM system prompt。
@MainActor
public protocol SkillProviding: AnyObject {
    /// 已注册的全部 Skill 贡献者（按注册顺序）。
    var contributors: [any SkillContributing] { get }

    /// 注册一个 Skill 贡献者。同 ID 重复注册时保留先注册者（幂等）。
    func addProvider(_ provider: any SkillContributing)

    /// 按 providerID 撤回贡献者。重复撤销无副作用。
    func removeProvider(providerID: String)

    /// 指定贡献者是否已注册。
    func isProviderRegistered(providerID: String) -> Bool

    /// 聚合全部贡献者提供的技能（按注册顺序，组内保持贡献者顺序）。
    ///
    /// - Returns: 全部技能。重名技能按「先注册优先」去重：后注册的同名
    ///   skill 不会覆盖前者，避免插件抢占系统内置技能名。
    func allSkills() -> [SkillMetadata]

    /// 按贡献者分组返回技能（UI 展示用）。
    func skillsGroupedByContributor() -> [(providerID: String, skills: [SkillMetadata])]

    // MARK: - Observation

    /// 注册贡献者集合变化观察者。
    ///
    /// 回调在主线程同步执行。返回值句柄释放或 `cancel()` 后自动停止接收。
    @discardableResult
    func addObserver(_ callback: @escaping (SkillProvidingEvent) -> Void) -> any SkillProvidingObserverHandle
}

/// Skill 管理事件。
@MainActor
public enum SkillProvidingEvent {
    /// 贡献者集合变化（注册 / 撤销后）。
    case contributorsChanged
}

/// Skill 管理观察者的注册令牌。
@MainActor
public protocol SkillProvidingObserverHandle: AnyObject {
    /// 停止接收事件。重复调用无副作用。
    func cancel()
}