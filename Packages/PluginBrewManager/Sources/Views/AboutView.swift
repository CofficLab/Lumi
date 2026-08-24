import LumiUI
import SwiftUI

/// Homebrew 管理插件关于视图 —— 以「命令清单」为主轴的落地页。
struct AboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            commandsSection
            capabilitiesSection
            packageTypesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "mug.fill",
            accent: theme.info,
            tagline: L("在应用里管理 Homebrew:查看已装包、检查更新、搜索安装、批量升级,图形化完成。"),
            chips: [L("Formula"), L("Cask"), L("批量升级")],
            metrics: [
                .init(value: "6", label: L("核心能力")),
                .init(value: "2", label: L("包类型")),
                .init(value: "gh", label: L("命令行内核"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 常用命令

    private var commandsSection: some View {
        LandingSection(title: L("图形化覆盖的常用命令"), icon: "terminal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "arrow.down.circle", title: "brew install", description: L("安装软件包"), mono: true),
                .init(icon: "magnifyingglass", title: "brew search", description: L("搜索可用包"), mono: true),
                .init(icon: "arrow.up.circle", title: "brew upgrade", description: L("批量 / 单包升级"), mono: true),
                .init(icon: "trash", title: "brew uninstall", description: L("卸载软件包"), mono: true),
                .init(icon: "info.circle", title: "brew info", description: L("查看包详情"), mono: true),
                .init(icon: "list.bullet", title: "brew list", description: L("已装包清单"), mono: true)
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.grid.2x2", tint: theme.info,
                      title: L("已装包浏览"),
                      description: L("查看所有已安装的 formula 与 cask,含版本、安装时间、依赖。")),
                .init(icon: "arrow.up.circle.badge.clock", tint: theme.warning,
                      title: L("更新检查"),
                      description: L("一眼对比当前与最新版本,规划升级策略。")),
                .init(icon: "magnifyingglass", title: L("包搜索"),
                      description: L("在 Homebrew 仓库中检索新包,浏览说明与主页。")),
                .init(icon: "arrow.down.arrow.up", tint: theme.success,
                      title: L("安装与卸载"),
                      description: L("安装新包或卸载已有包,跟踪进度并妥善处理错误。")),
                .init(icon: "arrow.up.square", tint: theme.primary,
                      title: L("批量升级"),
                      description: L("一次升级全部过期包,也可只升级指定的包。")),
                .init(icon: "checkmark.shield", tint: theme.warning,
                      title: L("环境检测"),
                      description: L("自动识别 Homebrew 是否安装,缺失时给出清晰指引。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 包类型

    private var packageTypesSection: some View {
        LandingSection(title: L("支持的包类型"), icon: "shippingbox") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "terminal", title: "Formula", description: L("命令行工具与库")),
                .init(icon: "app", title: "Cask", description: L("macOS 图形应用"))
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
