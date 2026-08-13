import LumiUI
import SwiftUI

// MARK: - About View

/// 剪贴板管理插件关于视图 —— 以产品落地页的形式介绍功能。
struct ClipboardManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            featuresSection
            howItWorksSection
            tipsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "square.on.square",
            accent: theme.info,
            tagline: L("自动记录每一次复制,随时回溯、搜索、复用,让剪贴板不再「阅后即焚」。"),
            chips: [L("历史记录"), L("文本片段"), L("全文搜索")],
            metrics: [
                .init(value: "4", label: L("核心功能")),
                .init(value: "3", label: L("内容类型")),
                .init(value: "∞", label: L("可回溯"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 核心功能

    private var featuresSection: some View {
        LandingSection(title: L("核心功能"), icon: "square.grid.2x2", subtitle: L("把剪贴板变成可检索的个人知识")) {
            LandingFeatureGrid(items: [
                .init(icon: "square.on.square", tint: theme.primary,
                      title: L("剪贴板历史"),
                      description: L("持续追踪剪贴板变化,随时访问之前的复制内容。")),
                .init(icon: "scissors", tint: theme.warning,
                      title: L("片段管理"),
                      description: L("保存常用文本片段,一键插入,告别重复输入。")),
                .init(icon: "magnifyingglass", tint: theme.info,
                      title: L("快速搜索"),
                      description: L("在历史记录中全文检索,瞬间定位需要的内容。")),
                .init(icon: "trash", tint: theme.error,
                      title: L("自动清理"),
                      description: L("按策略自动回收过期条目,占用始终可控。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("工作原理"), icon: "gearshape.2", subtitle: L("本地存储、随用随取")) {
            LandingStepFlow(steps: [
                .init(title: L("自动监听"), description: L("后台静默监听剪贴板的变化。"), icon: "antenna.radiowaves.left.and.right"),
                .init(title: L("本地入库"), description: L("历史安全保存在本地数据库,不上传任何服务器。")),
                .init(title: L("检索过滤"), description: L("提供搜索与筛选,快速找到目标条目。")),
                .init(title: L("多类型支持"), description: L("兼容文本、图片与富文本内容。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 使用技巧

    private var tipsSection: some View {
        LandingSection(title: L("使用技巧"), icon: "lightbulb") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    tipRow(L("用快捷键快速唤出剪贴板面板。"))
                    tipRow(L("把高频内容置顶,长期保持可用。"))
                    tipRow(L("按需调整自动清理策略,平衡历史与存储。"))
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
        ClipboardManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
