import Foundation
import KernelCore
import ProviderConversation
import ProviderMessage
import ProviderPluginControl
import ProviderPluginManaging
import ProviderTheme
import ProviderToast
import ProviderToolManager
import ProviderSettingView
import ProviderWebServer
import KitWebAPI
import KitWebServer
import LumiLoggingKit
import os

/// 本地 HTTP 服务的 V2 迁移实现。
///
/// 服务只绑定 `127.0.0.1`，默认端口 7310；保留真实 Hummingbird 监听、
/// 动态路由、自描述端点和旧版主题 API。启动失败不会阻断主应用。
///
/// 除了插件各自贡献的路由，本插件还装配**核心控制面**与
/// **Agent Tool 桥接**两组基础端点，让外部调用方能用统一方式操作
/// Lumi 的各个细节：
/// - `/api/v1/status` —— 服务与插件概览
/// - `/api/v1/plugins` —— 插件列表与启停
/// - `/api/v1/conversations` —— 会话与消息
/// - `/api/v1/tools` —— Agent Tool 的列表、schema 与调用
///
/// 其他插件通过 `WebRouteRegistrar` 声明式贡献自己的端点，其路由随插件
/// 启停自动上下线。
@MainActor
public final class WebServerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.web-server", category: "WebServer")
    public nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.web-server"
    public let order = 150

    /// 主题管理插件的 ID。主题端点以它的名义贡献，便于随其启停上下线。
    private static let themeManagerPluginID = "com.coffic.lumi.plugin.theme-manager"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.web-server",
        name: "Web Server",
        description: "为本地工具提供仅回环可访问的 HTTP API。",
        category: .integration,
        stage: .preview,
        policy: .required
    )

    private var server: LumiWebServer?
    /// 工具桥接器。工具注册表随插件启停变化，因此持有以便刷新索引。
    private var toolBridge: WebToolBridge?
    /// 插件路由贡献宿主：把插件声明的端点下发到服务，并随启停上下线。
    private var contributionHost: WebRouteContributionHost?
    /// 插件路由贡献登记表：收集各插件登记的端点。
    private let contributionTable = WebRouteContributionTable()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let server = LumiWebServer(port: 7310) { [weak kernel] activity in
            guard activity.isMutation, activity.isSuccess else { return }
            Task { @MainActor in
                guard let kernel else { return }
                let pluginID = activity.pluginID.split(separator: ".").last.map(String.init) ?? activity.pluginID
                kernel.resolveProvider((any ToastProviding).self)?.show(
                    activity.description ?? activity.path,
                    detail: "\(activity.method) · \(pluginID) · \(activity.statusCode)",
                    style: .info,
                    duration: 3
                )
            }
        }
        kernel.unregisterProvider((any WebServerProviding).self)
        try kernel.registerProvider((any WebServerProviding).self, server)
        self.server = server

        // 请求日志：保留最近若干条，供设置页展示与诊断。
        server.setRequestLogSink(WebInMemoryRequestLogSink())

        // 插件路由贡献宿主：登记与下发分离，插件不必关心服务何时就绪。
        let host = WebRouteContributionHost(
            server: server,
            pluginManager: kernel.resolveProvider((any PluginManaging).self)
        )
        host.startObserving()
        self.contributionHost = host

        registerThemeRoutes(kernel: kernel, server: server)

        // 核心控制面与工具桥接必须合并成**一次**注册：`LumiWebServer.register`
        // 对同一插件是整体替换语义，分两次注册会让后一组路由覆盖前一组。
        var bootRoutes = makeCoreRoutes(kernel: kernel, server: server)
        bootRoutes.append(contentsOf: makeToolRoutes(kernel: kernel))
        server.register(bootRoutes, forPlugin: id)

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: "Web Server",
                systemImage: "network",
                order: order
            ) {
                WebServerSettingsView(server: server)
            },
        ])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // 所有插件已启动，此刻把登记的贡献统一下发到服务。
        publishContributions(kernel: kernel)
        Task { await self.startIfNeeded() }
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        publishContributions(kernel: kernel)
        await startIfNeeded()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        await server?.stop()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let server = server
        Task { await server?.stop() }
        contributionHost?.stopObserving()
        contributionHost?.unpublishAll()
        self.contributionHost = nil
        self.server = nil
        self.toolBridge = nil
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
    }

    private func startIfNeeded() async {
        guard let server, !server.isRunning else { return }
        do {
            try await server.start()
            if let port = server.boundPort {
                if Self.verbose {
                    Self.logger.info("\(Self.t)listening on http://127.0.0.1:\(port)")
                }
            }
        } catch {
            Self.logger.error("\(Self.t)failed to start on port \(server.port): \(error.localizedDescription)")
        }
    }

    // MARK: - Route Contribution

    /// 为某个插件取得路由登记器。
    ///
    /// 插件通过它声明自己的 HTTP 端点。宿主在插件全部启动后统一下发，
    /// 并在插件启停时自动上下线。
    ///
    /// - Parameter pluginID: 归属插件 ID。
    /// - Returns: 登记器。
    public func registrar(for pluginID: String) -> WebRouteRegistrar {
        contributionTable.registrar(for: pluginID)
    }

    /// 把登记的贡献下发到服务。
    private func publishContributions(kernel: KernelCoreContainer) {
        guard let host = contributionHost else { return }
        for (pluginID, routes) in contributionTable.snapshot() {
            host.contribute(routes, forPlugin: pluginID)
        }
        host.publish()
    }

    // MARK: - Route Registration

    private func registerThemeRoutes(kernel: KernelCoreContainer, server: LumiWebServer) {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else { return }

        // 走「声明式贡献」路径：登记端点，由宿主在插件全部启动后统一下发。
        // 这与其它插件贡献自己端点的方式完全一致。
        let registrar = self.registrar(for: Self.themeManagerPluginID)
        registrar.contribute {
            WebRouteBuilder(prefix: "theme-manager")
                .get(
                    "/api/plugins/theme-manager/themes",
                    description: "列出全部主题及当前选中"
                ) { _ in
                    struct ThemeList: Encodable {
                        struct Item: Encodable { let id: String; let name: String; let selected: Bool }
                        let selectedThemeId: String?
                        let themes: [Item]
                    }
                    return try .json(ThemeList(
                        selectedThemeId: theme.selectedThemeId,
                        themes: theme.themes.map {
                            .init(id: $0.id, name: $0.displayName, selected: $0.id == theme.selectedThemeId)
                        }
                    ))
                }
                .post(
                    "/api/plugins/theme-manager/themes/:id/select",
                    description: "切换到指定主题"
                ) { request in
                    let themeID = try request.requirePathParameter("id")
                    do {
                        try theme.selectTheme(id: themeID)
                        return try .api(["currentThemeId": themeID] as [String: String])
                    } catch {
                        throw WebAPIError.notFound(message: error.localizedDescription)
                    }
                }
                .build()
        }
    }

    /// 构造核心控制面路由（状态、插件、会话）。
    private func makeCoreRoutes(kernel: KernelCoreContainer, server: LumiWebServer) -> [WebRoute] {
        let context = WebControlContext(
            conversations: kernel.resolveProvider((any ConversationManaging).self),
            messages: kernel.resolveProvider((any MessageManaging).self),
            toolManager: kernel.resolveProvider((any ToolManagerProviding).self),
            pluginControl: kernel.resolveProvider((any PluginControlling).self),
            pluginManager: kernel.resolveProvider((any PluginManaging).self)
        )

        let routes = WebControlRoutes.makeRoutes(context: context) { [weak server] in
            guard let server else {
                return WebStatusResponse.Service(
                    version: WebAPIVersion.current.rawValue,
                    uptime: 0,
                    routeCount: 0,
                    authenticationEnabled: false,
                    host: "127.0.0.1",
                    port: 0
                )
            }
            return WebStatusResponse.Service(
                version: WebAPIVersion.current.rawValue,
                uptime: server.uptime,
                routeCount: server.registeredRouteCount,
                authenticationEnabled: server.hasAuthentication,
                host: server.listenHost,
                port: server.boundPort ?? server.port
            )
        }

        return routes
    }

    /// 构造 Agent Tool 桥接路由。
    private func makeToolRoutes(kernel: KernelCoreContainer) -> [WebRoute] {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)tool manager unavailable, skipping tool bridge routes")
            }
            return []
        }

        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let bridge = WebToolBridge(
            toolManager: toolManager,
            conversationResolver: { @MainActor in
                conversations?.selectedConversationID
            }
        )
        self.toolBridge = bridge

        return WebToolRoutes.makeRoutes(bridge: bridge)
    }
}
