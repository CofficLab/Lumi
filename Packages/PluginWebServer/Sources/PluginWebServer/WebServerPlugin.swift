import Foundation
import KernelCore
import ProviderTheme
import ProviderToast
import ProviderSettingView
import ProviderWebServer
import KitWebServer
import KitSuperLog
import os

/// 旧版本地 HTTP 服务的 V2 迁移实现。
///
/// 服务只绑定 `127.0.0.1`，默认端口 7310；保留真实 Hummingbird 监听、
/// 动态路由、自描述端点和旧版主题 API。启动失败不会阻断主应用。
@MainActor
public final class WebServerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.web-server", category: "WebServer")
    public nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.web-server"
    public let order = 150
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.web-server",
        name: "Web Server",
        description: "为本地工具提供仅回环可访问的 HTTP API。",
        category: .integration,
        stage: .preview,
        policy: .required
    )

    private var server: LumiWebServer?

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
        registerThemeRoutes(kernel: kernel, server: server)
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
        Task { await self.startIfNeeded() }
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        await startIfNeeded()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        await server?.stop()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let server = server
        Task { await server?.stop() }
        self.server = nil
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

    private func registerThemeRoutes(kernel: KernelCoreContainer, server: LumiWebServer) {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else { return }
        server.register([
            WebRoute(
                id: "theme-manager.themes",
                method: .get,
                path: "/api/plugins/theme-manager/themes",
                description: "列出全部主题及当前选中"
            ) { _ in
                struct ThemeList: Encodable {
                    struct Item: Encodable { let id: String; let name: String; let selected: Bool }
                    let selectedThemeId: String?
                    let themes: [Item]
                }
                return try .json(ThemeList(
                    selectedThemeId: theme.selectedThemeId,
                    themes: theme.themes.map { .init(id: $0.id, name: $0.displayName, selected: $0.id == theme.selectedThemeId) }
                ))
            },
            WebRoute(
                id: "theme-manager.select",
                method: .post,
                path: "/api/plugins/theme-manager/themes/:id/select",
                description: "切换到指定主题"
            ) { request in
                guard let id = request.pathParameters["id"] else {
                    return try .json(["error": "missing theme id"], statusCode: 400)
                }
                do {
                    try theme.selectTheme(id: id)
                    return try .json(["ok": "true", "currentThemeId": id])
                } catch {
                    return try .json(["error": error.localizedDescription], statusCode: 404)
                }
            },
        ], forPlugin: id)
    }
}
