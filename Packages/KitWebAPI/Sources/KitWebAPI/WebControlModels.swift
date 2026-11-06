import Foundation

// MARK: - Status Response

/// `GET /api/v1/status` 的响应体。
///
/// 描述 Lumi 当前的运行状态：服务信息、版本、插件统计与当前会话。
public struct WebStatusResponse: Encodable, Sendable {
    /// 服务信息。
    public struct Service: Encodable, Sendable {
        /// API 版本。
        public let version: String
        /// 服务启动后的运行时长（秒）。
        public let uptime: TimeInterval
        /// 已注册的路由数量。
        public let routeCount: Int
        /// 是否启用鉴权。
        public let authenticationEnabled: Bool
        /// 服务监听地址。
        public let host: String
        /// 服务监听端口。
        public let port: Int

        public init(
            version: String,
            uptime: TimeInterval,
            routeCount: Int,
            authenticationEnabled: Bool,
            host: String,
            port: Int
        ) {
            self.version = version
            self.uptime = uptime
            self.routeCount = routeCount
            self.authenticationEnabled = authenticationEnabled
            self.host = host
            self.port = port
        }
    }

    /// 插件统计。
    public struct Plugins: Encodable, Sendable {
        /// 已注册插件总数。
        public let total: Int
        /// 已启用插件数。
        public let enabled: Int

        public init(total: Int, enabled: Int) {
            self.total = total
            self.enabled = enabled
        }
    }

    /// 服务信息。
    public let service: Service
    /// 插件统计。
    public let plugins: Plugins
    /// 当前选中的会话 ID。
    public let selectedConversationID: UUID?
    /// 已注册的 Agent 工具数量。
    public let toolCount: Int

    public init(
        service: Service,
        plugins: Plugins,
        selectedConversationID: UUID?,
        toolCount: Int
    ) {
        self.service = service
        self.plugins = plugins
        self.selectedConversationID = selectedConversationID
        self.toolCount = toolCount
    }
}

// MARK: - Plugin Response

/// `GET /api/v1/plugins` 的单个插件条目。
public struct WebPluginSummary: Encodable, Sendable {
    /// 插件 ID。
    public let id: String
    /// 插件显示名。
    public let name: String
    /// 插件描述。
    public let description: String
    /// 插件分类。
    public let category: String
    /// 插件成熟度阶段。
    public let stage: String
    /// 是否已启用。
    public let enabled: Bool
    /// 是否允许用户启停。
    public let configurable: Bool
    /// 该插件贡献的路由数量。
    public let routeCount: Int

    public init(
        id: String,
        name: String,
        description: String,
        category: String,
        stage: String,
        enabled: Bool,
        configurable: Bool,
        routeCount: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.stage = stage
        self.enabled = enabled
        self.configurable = configurable
        self.routeCount = routeCount
    }
}

// MARK: - Plugin Toggle Request

/// `POST /api/v1/plugins/:id/:action` 的请求体。
public struct WebPluginToggleRequest: Decodable, Sendable {
    /// 可选的原因说明，写入插件启停日志。
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

// MARK: - Plugin Toggle Response

/// 插件启停操作的响应体。
public struct WebPluginToggleResponse: Encodable, Sendable {
    /// 插件 ID。
    public let id: String
    /// 启停后的状态。
    public let enabled: Bool

    public init(id: String, enabled: Bool) {
        self.id = id
        self.enabled = enabled
    }
}

// MARK: - Conversation Response

/// `GET /api/v1/conversations` 的单个会话条目。
public struct WebConversationSummary: Encodable, Sendable {
    /// 会话 ID。
    public let id: UUID
    /// 会话标题（可能为 nil，表示未命名）。
    public let title: String?
    /// 会话预览文本。
    public let preview: String
    /// 创建时间。
    public let createdAt: Date
    /// 最后活跃时间。
    public let updatedAt: Date
    /// 关联的项目路径。
    public let projectPath: String?
    /// 使用的模型 ID。
    public let modelID: String?
    /// 自动化等级（a1/a2/a3）。
    public let automationLevel: String?

    public init(
        id: UUID,
        title: String?,
        preview: String,
        createdAt: Date,
        updatedAt: Date,
        projectPath: String?,
        modelID: String?,
        automationLevel: String?
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectPath = projectPath
        self.modelID = modelID
        self.automationLevel = automationLevel
    }
}

// MARK: - Message Response

/// `GET /api/v1/conversations/:id/messages` 的单条消息。
public struct WebMessageSummary: Encodable, Sendable {
    /// 消息 ID。
    public let id: UUID
    /// 消息角色（user/assistant/system/tool）。
    public let role: String
    /// 消息正文。
    public let content: String
    /// 创建时间。
    public let createdAt: Date
    /// 是否为错误消息。
    public let isError: Bool
    /// 关联的回合 ID。
    public let turnID: UUID?

    public init(
        id: UUID,
        role: String,
        content: String,
        createdAt: Date,
        isError: Bool,
        turnID: UUID?
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.isError = isError
        self.turnID = turnID
    }
}
