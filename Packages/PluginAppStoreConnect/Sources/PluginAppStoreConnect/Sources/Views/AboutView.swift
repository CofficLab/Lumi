import LumiUI
import SwiftUI

// MARK: - About View

/// App Store Connect 插件关于视图 —— 以产品落地页的形式介绍功能。
struct AboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            featuresSection
            workflowSection
            tipsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "shippingbox",
            accent: theme.primary,
            tagline: L("在应用里直接管理 App Store Connect:应用、元数据、截图与版本,一站式提交上架。"),
            chips: [L("元数据"), L("截图"), L("版本管理")],
            metrics: [
                .init(value: "4", label: L("核心能力")),
                .init(value: "1", label: L("API 密钥")),
                .init(value: "0", label: L("离开应用"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 核心能力

    private var featuresSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2", subtitle: L("覆盖上架日常的各个环节")) {
            LandingFeatureGrid(items: [
                .init(icon: "app.dashed", tint: theme.primary,
                      title: L("应用管理"),
                      description: L("集中管理你的 App Store Connect 应用、元数据与截图。")),
                .init(icon: "photo.on.rectangle", tint: theme.info,
                      title: L("截图管理"),
                      description: L("上传、预览并整理各机型的应用截图。")),
                .init(icon: "text.alignleft", tint: theme.warning,
                      title: L("元数据编辑"),
                      description: L("编辑应用信息、描述与关键词等本地化文案。")),
                .init(icon: "clock.arrow.circlepath", tint: theme.success,
                      title: L("版本管理"),
                      description: L("创建并管理用于提交的各个应用版本。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作流

    private var workflowSection: some View {
        LandingSection(title: L("工作流"), icon: "arrow.triangle.branch.and.merge", subtitle: L("从连接到提交,四步完成")) {
            LandingStepFlow(steps: [
                .init(title: L("连接 API"), description: L("在插件设置中配置 App Store Connect API 密钥。"), icon: "key.fill"),
                .init(title: L("拉取应用"), description: L("获取应用信息与现有元数据。")),
                .init(title: L("编辑与上传"), description: L("修改文案、上传截图,实时预览效果。")),
                .init(title: L("提交变更"), description: L("将改动直接提交到 App Store Connect。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 使用提示

    private var tipsSection: some View {
        LandingSection(title: L("使用提示"), icon: "lightbulb") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    tipRow(L("先在插件设置里配置好 API 密钥。"))
                    tipRow(L("从工具栏选择要管理的应用。"))
                    tipRow(L("所有改动都会直接提交到 App Store Connect。"))
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
        AppStoreConnectLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        AboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
