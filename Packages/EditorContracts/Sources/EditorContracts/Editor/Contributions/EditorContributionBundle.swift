import Foundation

// MARK: - Feature Provider 基协议（§9.4）

/// 所有编辑器 Feature Provider 的基协议。
///
/// Provider 由插件在 `EditorContributionBundle.providers` 中贡献；
/// Host 按 selector/priority/trust 解析并聚合（§9.5）。
/// 实现必须 `Sendable`（actor 或真正的 Sendable 值），耗时工作不得占用主线程（§8.8）。
public protocol EditorFeatureProvider: AnyObject, Sendable {
    /// Provider 在插件内唯一的 id（完整 ID 由 Host 加 plugin namespace，§24）。
    var id: String { get }

    /// 适用文档选择器。
    var selector: EditorDocumentSelector { get }

    /// 解析优先级，数值越大越优先。
    var priority: Int { get }

    /// 所需工作区信任等级。
    var requiredTrust: EditorWorkspaceTrustRequirement { get }
}

public extension EditorFeatureProvider {
    var priority: Int { 0 }
    var requiredTrust: EditorWorkspaceTrustRequirement { .none }
    var selector: EditorDocumentSelector { .any }
}

// MARK: - 语言贡献（§9.1 / §11）

/// 一个语言贡献：语言描述符 + 可选 grammar provider + 高亮贡献者。
///
/// 迁移期映射：Host 把它落到现有 `LanguageRegistry` / 高亮管线；
/// Phase 4 之后语言插件只面向本类型，不再实现 `EditorPlugin.registerExtensions`。
///
/// `grammar` / `highlightContributors` 是插件贡献的 class 引用（kernel 版协议
/// 仅为 `AnyObject` 约束），注册后视为只读共享，故用 `@unchecked Sendable`。
public struct EditorLanguageContribution: @unchecked Sendable {
    public let language: EditorLanguageDescriptor

    /// Tree-sitter grammar（kernel 版协议，桥接到 EditorLanguageRuntime）。
    public let grammar: (any LanguageGrammarProviding)?

    /// 高亮贡献者（kernel 版标记协议）。
    public let highlightContributors: [any EditorHighlightContributor]

    public init(
        language: EditorLanguageDescriptor,
        grammar: (any LanguageGrammarProviding)? = nil,
        highlightContributors: [any EditorHighlightContributor] = []
    ) {
        self.language = language
        self.grammar = grammar
        self.highlightContributors = highlightContributors
    }
}

// MARK: - 命令与设置贡献（占位，§14/§15 完整接入在后续阶段）

/// 插件贡献的命令描述（声明式；执行路由到 Host 命令系统）。
public struct EditorCommandContribution: Equatable, Sendable {
    public let id: EditorCommandID
    public let title: String
    public let category: String

    public init(id: EditorCommandID, title: String, category: String = "") {
        self.id = id
        self.title = title
        self.category = category
    }
}

/// 插件贡献的设置声明（schema 分区，Phase 后续接入）。
public struct EditorSettingContribution: Equatable, Sendable {
    public let key: EditorSettingKey
    public let title: String

    public init(key: EditorSettingKey, title: String) {
        self.key = key
        self.title = title
    }
}

// MARK: - 贡献包（§9.1）

/// 插件的完整编辑器贡献包。
///
/// **事务语义（§9.3）**：
/// - 构建阶段只创建描述符和 Provider，**不得**启动 Language Server、watcher 或后台任务；
///   资源启动由 Host 在 Bundle 原子安装成功后执行。
/// - Host 按 `pluginID` 原子安装/替换/撤回；`generation` 由 PluginManager 盖戳，
///   插件不能伪造归属。
public struct EditorContributionBundle {
    /// 归属插件 id（由 PluginManager 校验后写入，覆盖插件自报值）。
    public let pluginID: String

    /// 声明的 API 版本；major 不兼容时拒绝安装。
    public let apiVersion: EditorPluginAPIVersion

    /// 装配代次（由 PluginManager 递增盖戳，用于取消旧代请求）。
    public let generation: UInt64

    /// 语言贡献（描述符 + grammar + 高亮）。
    public let languages: [EditorLanguageContribution]

    /// Feature Provider（补全/Hover 等，Phase 5 接入解析管线）。
    public let providers: [any EditorFeatureProvider]

    /// 命令贡献。
    public let commands: [EditorCommandContribution]

    /// 设置贡献。
    public let settings: [EditorSettingContribution]

    public init(
        pluginID: String,
        apiVersion: EditorPluginAPIVersion = .current,
        generation: UInt64 = 0,
        languages: [EditorLanguageContribution] = [],
        providers: [any EditorFeatureProvider] = [],
        commands: [EditorCommandContribution] = [],
        settings: [EditorSettingContribution] = []
    ) {
        self.pluginID = pluginID
        self.apiVersion = apiVersion
        self.generation = generation
        self.languages = languages
        self.providers = providers
        self.commands = commands
        self.settings = settings
    }

    /// 携带新 pluginID/generation 的副本（PluginManager 盖戳用）。
    public func stamped(pluginID: String, generation: UInt64) -> EditorContributionBundle {
        EditorContributionBundle(
            pluginID: pluginID,
            apiVersion: apiVersion,
            generation: generation,
            languages: languages,
            providers: providers,
            commands: commands,
            settings: settings
        )
    }

    /// 是否可与给定宿主版本共存（§24：major 必须一致且不高于宿主）。
    public func isCompatible(with host: EditorPluginAPIVersion) -> Bool {
        apiVersion.isCompatible(with: host)
    }

    /// 校验内部一致性：语言 id / Provider id / 命令 id 不得重复。
    public var validationIssues: [String] {
        var issues: [String] = []
        let languageIDs = languages.map(\.language.languageId)
        if Set(languageIDs).count != languageIDs.count {
            issues.append("duplicate language ids: \(languageIDs)")
        }
        let providerIDs = providers.map(\.id)
        if Set(providerIDs).count != providerIDs.count {
            issues.append("duplicate provider ids: \(providerIDs)")
        }
        let commandIDs = commands.map(\.id.rawValue)
        if Set(commandIDs).count != commandIDs.count {
            issues.append("duplicate command ids: \(commandIDs)")
        }
        if languageIDs.contains(where: { $0.isEmpty }) {
            issues.append("empty language id")
        }
        return issues
    }
}
