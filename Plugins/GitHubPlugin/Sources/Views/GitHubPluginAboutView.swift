import LumiUI
import SwiftUI

/// GitHub 插件关于视图 —— 以产品落地页的形式介绍功能。
public struct GitHubPluginAboutView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            featuresSection
            workflowSection
            privacySection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "network",
            accent: theme.primary,
            tagline: L("GitHub CLI 检测、生态洞察知识库与完整的 GitHub API 工具集:仓库查询、Issue 管理、趋势浏览一站搞定。"),
            chips: [L("CLI 检测"), L("生态洞察"), L("API 工具"), L("趋势项目")],
            metrics: [
                .init(value: "4", label: L("核心能力")),
                .init(value: "gh", label: L("命令行")),
                .init(value: "0", label: L("外发数据"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 核心能力

    private var featuresSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2", subtitle: L("把 GitHub 能力直接带进对话")) {
            LandingFeatureGrid(items: [
                .init(icon: "terminal", tint: theme.primary,
                      title: L("CLI 检测"),
                      description: L("自动检测系统中是否已安装 GitHub CLI (gh)。")),
                .init(icon: "books.vertical", tint: theme.info,
                      title: L("生态洞察"),
                      description: L("基于本地知识库的 GitHub 生态系统问答。")),
                .init(icon: "curlybraces", tint: theme.warning,
                      title: L("API 工具"),
                      description: L("通过 GitHub API 进行仓库查询、Issue 管理等操作。")),
                .init(icon: "chart.line.uptrend.xyaxis", tint: theme.success,
                      title: L("趋势项目"),
                      description: L("浏览 GitHub 上的热门项目与趋势。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 典型用法

    private var workflowSection: some View {
        LandingSection(title: L("典型用法"), icon: "arrow.triangle.branch.and.merge", subtitle: L("几步即可开始")) {
            LandingStepFlow(steps: [
                .init(title: L("检测 gh"), description: L("插件自动识别本机的 GitHub CLI 安装状态。"), icon: "checkmark.seal.fill"),
                .init(title: L("配置令牌"), description: L("在设置中填入 Personal Access Token 以调用 API。")),
                .init(title: L("查询与管理"), description: L("检索仓库、管理 Issue 与 PR、查看趋势项目。")),
                .init(title: L("本地洞察"), description: L("直接向知识库提问 GitHub 生态相关问题。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 隐私

    private var privacySection: some View {
        LandingSection(title: L("隐私"), icon: "lock.shield") {
            AppCard(style: .subtle, cornerRadius: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.success)
                    Text(L("Token 仅存储在本地,不会上传到任何服务器。"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        GitHubPluginAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
