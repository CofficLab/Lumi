import Foundation
import KitAgentTool
import ProviderConversation
import ProviderMessage
import ProviderPluginControl
import ProviderPluginManaging
import ProviderToolManager
import ProviderWebServer

// MARK: - Control Plane Context

/// 控制面 API 所需的依赖集合。
///
/// 用一个结构体集中承载，避免控制面路由直接依赖具体插件包——插件包只负责
/// 在装配时把 Provider 塞进来。
@MainActor
public struct WebControlContext {
    /// 会话管理。
    public var conversations: (any ConversationManaging)?
    /// 消息管理。
    public var messages: (any MessageManaging)?
    /// 工具管理。
    public var toolManager: (any ToolManagerProviding)?
    /// 插件启停控制。
    public var pluginControl: (any PluginControlling)?
    /// 插件枚举与管理。
    public var pluginManager: (any PluginManaging)?

    public init(
        conversations: (any ConversationManaging)? = nil,
        messages: (any MessageManaging)? = nil,
        toolManager: (any ToolManagerProviding)? = nil,
        pluginControl: (any PluginControlling)? = nil,
        pluginManager: (any PluginManaging)? = nil
    ) {
        self.conversations = conversations
        self.messages = messages
        self.toolManager = toolManager
        self.pluginControl = pluginControl
        self.pluginManager = pluginManager
    }
}

// MARK: - Control Plane Routes

/// 核心控制面 API 的路由。
///
/// 提供「外部通过 HTTP 操作 Lumi 各个细节」的基础控制面：
/// - `GET  /api/v1/status` —— 服务与插件概览
/// - `GET  /api/v1/plugins` —— 列出全部插件
/// - `POST /api/v1/plugins/:id/enable` —— 启用插件
/// - `POST /api/v1/plugins/:id/disable` —— 禁用插件
/// - `GET  /api/v1/conversations` —— 列出会话（分页）
/// - `GET  /api/v1/conversations/:id` —— 查看会话详情
/// - `GET  /api/v1/conversations/:id/messages` —— 查看会话消息（分页）
/// - `POST /api/v1/conversations/:id/select` —— 切换当前会话
/// - `POST /api/v1/conversations/:id/title` —— 重命名会话
/// - `DELETE /api/v1/conversations/:id` —— 删除会话
public enum WebControlRoutes {
    /// 构造控制面路由。
    ///
    /// - Parameters:
    ///   - context: 依赖集合。
    ///   - serviceInfo: 服务运行信息提供者（端口、鉴权状态、路由数等）。
    ///   - prefix: 路径前缀，默认 `/api/v1`。
    /// - Returns: 可直接注册的路由列表。
    public static func makeRoutes(
        context: WebControlContext,
        serviceInfo: @escaping @MainActor @Sendable () -> WebStatusResponse.Service,
        prefix: String = "/api/v1"
    ) -> [WebRoute] {
        let builder = WebRouteBuilder(prefix: "control")
        return builder
            .get("\(prefix)/status", description: "服务状态、插件统计与当前会话") { _ in
                let service = serviceInfo()
                let plugins = pluginStats(context: context)
                let selected = context.conversations?.selectedConversationID
                let toolCount = context.toolManager?.allTools().count ?? 0
                return try .api(
                    WebStatusResponse(
                        service: service,
                        plugins: plugins,
                        selectedConversationID: selected,
                        toolCount: toolCount
                    )
                )
            }
            .get("\(prefix)/plugins", description: "列出全部已注册插件及其启用状态") { _ in
                try .api(pluginSummaries(context: context))
            }
            .post("\(prefix)/plugins/:id/enable", description: "启用指定插件") { request in
                let id = try request.requirePathParameter("id")
                return try await togglePlugin(id: id, enabled: true, context: context)
            }
            .post("\(prefix)/plugins/:id/disable", description: "禁用指定插件") { request in
                let id = try request.requirePathParameter("id")
                return try await togglePlugin(id: id, enabled: false, context: context)
            }
            .get("\(prefix)/conversations", description: "列出会话（支持 offset/limit 分页）") { request in
                guard let conversations = context.conversations else {
                    throw WebAPIError.unavailable(message: "Conversation manager is not available")
                }
                let all = conversations.sortedConversations.map { summary in
                    WebConversationSummary(
                        id: summary.id,
                        title: summary.title,
                        preview: summary.preview,
                        createdAt: summary.createdAt,
                        updatedAt: summary.updatedAt,
                        projectPath: summary.projectPath,
                        modelID: summary.modelID,
                        automationLevel: summary.automationLevel?.rawValue
                    )
                }
                return try .apiPage(WebPageResult(items: all, pagination: request.pagination))
            }
            .get("\(prefix)/conversations/:id", description: "查看单个会话的详情") { request in
                guard let conversations = context.conversations else {
                    throw WebAPIError.unavailable(message: "Conversation manager is not available")
                }
                let id = try request.requirePathParameter("id")
                guard let uuid = UUID(uuidString: id) else {
                    throw WebAPIError.badRequest(message: "Invalid conversation id", field: "id")
                }
                guard let summary = await conversations.fetchConversation(id: uuid) else {
                    throw WebAPIError.notFound(message: "Conversation not found: \(id)")
                }
                return try .api(
                    WebConversationSummary(
                        id: summary.id,
                        title: summary.title,
                        preview: summary.preview,
                        createdAt: summary.createdAt,
                        updatedAt: summary.updatedAt,
                        projectPath: summary.projectPath,
                        modelID: summary.modelID,
                        automationLevel: summary.automationLevel?.rawValue
                    )
                )
            }
            .get("\(prefix)/conversations/:id/messages", description: "查看会话的消息列表") { request in
                guard let messages = context.messages else {
                    throw WebAPIError.unavailable(message: "Message manager is not available")
                }
                let id = try request.requirePathParameter("id")
                guard let uuid = UUID(uuidString: id) else {
                    throw WebAPIError.badRequest(message: "Invalid conversation id", field: "id")
                }
                let all = messages.messages(for: uuid).map { message in
                    WebMessageSummary(
                        id: message.id,
                        role: message.role.rawValue,
                        content: message.content,
                        createdAt: message.createdAt,
                        isError: message.isError,
                        turnID: message.turnID
                    )
                }
                return try .apiPage(WebPageResult(items: all, pagination: request.pagination))
            }
            .post("\(prefix)/conversations/:id/select", description: "切换当前选中的会话") { request in
                guard let conversations = context.conversations else {
                    throw WebAPIError.unavailable(message: "Conversation manager is not available")
                }
                let id = try request.requirePathParameter("id")
                guard let uuid = UUID(uuidString: id) else {
                    throw WebAPIError.badRequest(message: "Invalid conversation id", field: "id")
                }
                conversations.selectConversation(id: uuid)
                return try .api(["selected": uuid.uuidString] as [String: String])
            }
            .post("\(prefix)/conversations/:id/title", description: "重命名会话") { request in
                guard let conversations = context.conversations else {
                    throw WebAPIError.unavailable(message: "Conversation manager is not available")
                }
                let id = try request.requirePathParameter("id")
                guard let uuid = UUID(uuidString: id) else {
                    throw WebAPIError.badRequest(message: "Invalid conversation id", field: "id")
                }
                let payload = try request.decodeBodyOrThrow(WebTitleRequest.self)
                let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else {
                    throw WebAPIError.badRequest(message: "Title must not be empty", field: "title")
                }
                guard await conversations.updateConversationTitleAndWait(title, for: uuid) else {
                    throw WebAPIError.notFound(message: "Conversation not found: \(id)")
                }
                return try .api(["id": uuid.uuidString, "title": title] as [String: String])
            }
            .delete("\(prefix)/conversations/:id", description: "删除会话") { request in
                guard let conversations = context.conversations else {
                    throw WebAPIError.unavailable(message: "Conversation manager is not available")
                }
                let id = try request.requirePathParameter("id")
                guard let uuid = UUID(uuidString: id) else {
                    throw WebAPIError.badRequest(message: "Invalid conversation id", field: "id")
                }
                conversations.deleteConversation(id: uuid)
                return try .api(["deleted": uuid.uuidString] as [String: String])
            }
            .build()
    }

    // MARK: - Helpers

    /// 统计插件数量。
    @MainActor
    private static func pluginStats(context: WebControlContext) -> WebStatusResponse.Plugins {
        guard let manager = context.pluginManager else {
            return WebStatusResponse.Plugins(total: 0, enabled: 0)
        }
        let all = manager.allPlugins
        let enabled = all.filter { manager.isEnabled(id: $0.id) }.count
        return WebStatusResponse.Plugins(total: all.count, enabled: enabled)
    }

    /// 列出插件摘要。
    @MainActor
    private static func pluginSummaries(context: WebControlContext) -> [WebPluginSummary] {
        guard let manager = context.pluginManager else { return [] }
        return manager.allPlugins.map { plugin in
            WebPluginSummary(
                id: plugin.id,
                name: plugin.metadata.name,
                description: plugin.metadata.description,
                category: plugin.metadata.category.rawValue,
                stage: plugin.metadata.stage.rawValue,
                enabled: manager.isEnabled(id: plugin.id),
                configurable: plugin.metadata.policy.isConfigurable,
                routeCount: 0
            )
        }
    }

    /// 启用或禁用插件。
    @MainActor
    private static func togglePlugin(
        id: String,
        enabled: Bool,
        context: WebControlContext
    ) async throws -> WebRouteResponse {
        guard let control = context.pluginControl else {
            throw WebAPIError.unavailable(message: "Plugin control is not available")
        }
        guard let manager = context.pluginManager,
              let plugin = manager.plugin(id: id)
        else {
            throw WebAPIError.notFound(message: "Plugin not found: \(id)")
        }
        guard plugin.metadata.policy.isConfigurable else {
            throw WebAPIError.forbidden(
                message: "Plugin '\(id)' cannot be toggled (policy: \(plugin.metadata.policy.rawValue))"
            )
        }

        let success = enabled
            ? await control.enablePlugin(id: id)
            : await control.disablePlugin(id: id)

        guard success else {
            let reason = control.lastErrorDescription ?? "Unknown error"
            throw WebAPIError.conflict(message: "Failed to \(enabled ? "enable" : "disable") plugin: \(reason)")
        }

        return try .api(WebPluginToggleResponse(id: id, enabled: enabled))
    }
}

// MARK: - Title Request

/// `POST /api/v1/conversations/:id/title` 的请求体。
public struct WebTitleRequest: Decodable, Sendable {
    /// 新标题。
    public let title: String

    public init(title: String) {
        self.title = title
    }
}
