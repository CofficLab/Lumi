import LumiUI
import SwiftUI

/// 数据库管理插件关于视图 —— 以「统一浏览器 + 多引擎」为主轴的落地页。
struct AboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            capabilitiesSection
            enginesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "table.column.header",
            accent: theme.primary,
            tagline: L("一套界面连接 SQLite、MySQL、PostgreSQL、Redis:浏览表、安全编辑、运行自定义 SQL。"),
            chips: [L("多数据库"), L("统一浏览"), L("安全编辑"), L("自定义 SQL")],
            metrics: [
                .init(value: "4", label: L("数据库引擎")),
                .init(value: "SSL", label: L("可选加密")),
                .init(value: "事务", label: L("安全提交"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "rectangle.split.3x1",
            tint: theme.primary,
            title: L("跨引擎的统一数据浏览器"),
            message: L("在不同数据库之间浏览表、视图与例程,支持分页与排序,体验保持一致。")
        ) {
            HStack(spacing: 6) {
                AppTag(L("分页"), style: .subtle)
                AppTag(L("排序"), style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "server.rack", tint: theme.primary,
                      title: L("多数据库支持"),
                      description: L("连接 SQLite、MySQL、PostgreSQL、Redis,可选 SSL/TLS。")),
                .init(icon: "rectangle.split.3x1", tint: theme.info,
                      title: L("统一数据浏览器"),
                      description: L("跨引擎浏览表、视图与例程,支持分页与排序。")),
                .init(icon: "pencil.line", tint: theme.warning,
                      title: L("安全内联编辑"),
                      description: L("编辑单元格与行,预览生成的 SQL,在事务中保存。")),
                .init(icon: "arrow.uturn.backward.circle", tint: theme.success,
                      title: L("撤销与重做"),
                      description: L("提交前可暂存改动,完整支持撤销 / 重做。")),
                .init(icon: "curlybraces", tint: theme.error,
                      title: L("自定义 SQL"),
                      description: L("运行你自己的 SQL,查看分页可排序的结果。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 支持的数据库

    private var enginesSection: some View {
        LandingSection(title: L("支持的数据库"), icon: "internaldrive") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "cylinder", title: "SQLite", description: L("本地嵌入式")),
                .init(icon: "server.rack", title: "MySQL", description: L("可选 SSL/TLS")),
                .init(icon: "server.rack", title: "PostgreSQL", description: L("可选 SSL/TLS")),
                .init(icon: "bolt", title: "Redis", description: L("键值存储"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        AboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
