import Foundation

public enum PluginEnablePolicy: String, Codable, Sendable {
    /// 宿主必需能力，不能由用户禁用。
    case required
    /// 始终启用，用户不可禁用（对应旧版 `LumiPluginPolicy.alwaysOn`）。
    case alwaysOn
    /// 默认启用，用户可以在运行时禁用。
    case enabledByDefault
    /// 默认不启动运行时资源，由用户显式启用。
    case disabledByDefault
}

public extension PluginEnablePolicy {
    /// 用户是否可配置此插件的启用状态（对应旧版 `LumiPluginPolicy.isConfigurable`）。
    var isConfigurable: Bool {
        switch self {
        case .enabledByDefault, .disabledByDefault:
            true
        case .required, .alwaysOn:
            false
        }
    }

    /// 默认是否启用（对应旧版 `LumiPluginPolicy.enabledByDefault`）。
    var enabledByDefault: Bool {
        switch self {
        case .required, .alwaysOn, .enabledByDefault:
            true
        case .disabledByDefault:
            false
        }
    }
}

public enum PluginCategory: String, Codable, Sendable {
    case core
    case chat
    case llm
    case editor
    case project
    case system
    case design
    case integration
    case general
}

public enum PluginStage: String, Codable, Sendable {
    case experimental
    case preview
    case stable
    case deprecated
}

public struct PluginPermission: Hashable, Codable, Sendable {
    public let id: String
    public let reason: String

    public init(id: String, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct PluginMetadata: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let version: String
    public let category: PluginCategory
    public let stage: PluginStage
    public let policy: PluginEnablePolicy
    public let permissions: [PluginPermission]

    public init(
        id: String,
        name: String? = nil,
        description: String = "",
        version: String = "1.0.0",
        category: PluginCategory = .general,
        stage: PluginStage = .stable,
        policy: PluginEnablePolicy = .alwaysOn,
        permissions: [PluginPermission] = []
    ) {
        self.id = id
        self.name = name ?? id
        self.description = description
        self.version = version
        self.category = category
        self.stage = stage
        self.policy = policy
        self.permissions = permissions
    }
}
