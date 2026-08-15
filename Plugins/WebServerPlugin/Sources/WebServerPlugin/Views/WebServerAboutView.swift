import KernelLumi
import LumiUI
import SwiftUI

/// 本地 Web 服务插件关于视图 —— 以「本地 HTTP 聚合入口」为主轴的落地页。
struct WebServerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            requirementsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "network",
            accent: theme.info,
            tagline: L(
                en: "A local HTTP service on 127.0.0.1 that aggregates every plugin's web routes, so local tools can drive plugin capabilities over HTTP.",
                zh: "在 127.0.0.1 上启动本地 HTTP 服务,聚合所有插件贡献的 webRoutes,让本地工具通过 HTTP API 调用插件能力。"
            ),
            chips: [
                L(en: "Localhost Only", zh: "仅本机回环"),
                L(en: "Route Aggregation", zh: "路由聚合"),
                L(en: "Hot Plug", zh: "热插拔"),
                L(en: "On by Default", zh: "默认启用")
            ],
            metrics: [
                .init(value: "7310", label: L(en: "default port", zh: "默认端口")),
                .init(value: "127.0.0.1", label: L(en: "binds to", zh: "监听地址")),
                .init(value: L(en: "All plugins", zh: "所有插件"), label: L(en: "routes shared", zh: "路由来源"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L(en: "Core Capabilities", zh: "核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "server.rack", tint: theme.info,
                      title: L(en: "Local HTTP Service", zh: "本地 HTTP 服务"),
                      description: L(en: "Listens on 127.0.0.1:7310; plugin capabilities become HTTP-callable.", zh: "监听 127.0.0.1:7310,插件能力可通过 HTTP API 被本地工具调用。")),
                .init(icon: "point.3.connected.trianglepath.dotted", tint: theme.primary,
                      title: L(en: "Route Aggregation", zh: "路由聚合"),
                      description: L(en: "Collects WebRoutes declared by all enabled plugins into one server.", zh: "自动收集所有启用插件声明的 WebRoute 到同一个服务。")),
                .init(icon: "bolt.horizontal", tint: theme.success,
                      title: L(en: "Hot Plug", zh: "热插拔"),
                      description: L(en: "Enabling or disabling a plugin registers or withdraws its routes instantly.", zh: "插件启用 / 禁用时路由即时注册 / 撤回,无需重启服务。")),
                .init(icon: "shield.lefthalf.filled", tint: theme.warning,
                      title: L(en: "Loopback Only", zh: "仅监听回环"),
                      description: L(en: "Binds to the loopback interface only — nothing is exposed to the network.", zh: "仅监听本地回环地址,不向网络暴露任何端口。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 说明

    private var requirementsSection: some View {
        LandingSection(title: L(en: "Good to Know", zh: "使用说明"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "checkmark.circle",
                      title: L(en: "On by default (opt-out); turn it off in Plugin Manager anytime.", zh: "默认启用(optOut),可随时在插件管理中关闭。")),
                .init(icon: "exclamationmark.triangle",
                      title: L(en: "A busy port won't crash the app — the service simply stays unavailable.", zh: "端口被占用等启动失败不会中断 App,服务保持不可用状态。")),
                .init(icon: "bell",
                      title: L(en: "Incoming requests surface a toast in the UI.", zh: "收到请求时会在 UI 上弹出 toast 反馈。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(en: String, zh: String) -> String {
        LumiLanguagePreference.current.localized(en: en, zh: zh)
    }
}

#Preview {
    ScrollView {
        WebServerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
