import LumiUI
import SwiftUI

// MARK: - About View

/// 终端插件关于视图 —— 以产品落地页的形式介绍功能。
struct TerminalAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            featuresSection
            shortcutsSection
            tipsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "terminal",
            accent: theme.primary,
            tagline: L("应用内置的原生交互式终端,多标签并行、跟随主题,随时随手执行命令。"),
            chips: [L("多标签"), L("Shell 集成"), L("主题同步")],
            metrics: [
                .init(value: "4", label: L("核心能力")),
                .init(value: "∞", label: L("标签页")),
                .init(value: "0", label: L("额外配置"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 核心能力

    private var featuresSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2", subtitle: L("为开发者打造的终端体验")) {
            LandingFeatureGrid(items: [
                .init(icon: "rectangle.on.rectangle", tint: theme.primary,
                      title: L("多标签终端"),
                      description: L("并行打开多个终端标签,各自独立的会话同时运行。")),
                .init(icon: "wand.and.stars", tint: theme.info,
                      title: L("Shell 集成"),
                      description: L("支持 zsh、bash 等主流 Shell,完整的转义序列与按键。")),
                .init(icon: "paintbrush", tint: theme.warning,
                      title: L("主题匹配"),
                      description: L("自动跟随当前编辑器主题,视觉与整体保持一致。")),
                .init(icon: "folder", tint: theme.success,
                      title: L("项目目录"),
                      description: L("每个标签默认在当前项目根目录下启动。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 快捷键

    private var shortcutsSection: some View {
        LandingSection(title: L("快捷键"), icon: "keyboard", subtitle: L("高效管理你的标签页")) {
            LandingShortcutList(shortcuts: [
                .init(keys: "⌘T", description: L("新建标签页")),
                .init(keys: "⌘W", description: L("关闭当前标签页")),
                .init(keys: "⌘1…9", description: L("切换到第 N 个标签页")),
                .init(keys: "⌃ + 点击", description: L("右键标签栏查看更多操作"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 使用提示

    private var tipsSection: some View {
        LandingSection(title: L("使用提示"), icon: "lightbulb") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    tipRow(L("从侧边栏的终端图标随时打开面板。"))
                    tipRow(L("为不同任务建立独立标签,互不干扰。"))
                    tipRow(L("主题会自动与编辑器同步,无需手动设置。"))
                }
            }
        }
        .landingAppear(delay: 0.15)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13))
                .foregroundStyle(theme.warning)
            Text(text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        TerminalAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
