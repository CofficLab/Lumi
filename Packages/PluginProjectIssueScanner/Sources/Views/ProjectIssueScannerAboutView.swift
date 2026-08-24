import LumiUI
import SwiftUI

/// 项目问题扫描插件关于视图 —— 以「后台工作流」为主轴的落地页。
struct ProjectIssueScannerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            workflowSection
            capabilitiesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "viewfinder",
            accent: theme.error,
            tagline: L("在系统空闲时自动扫描项目已知问题,把上下文提示给 LLM,让助手更懂你的项目——全程后台静默。"),
            chips: [L("空闲扫描"), L("AI 提示"), L("问题追踪"), L("后台运行")],
            metrics: [
                .init(value: "空闲", label: L("触发时机")),
                .init(value: "AI", label: L("上下文提示")),
                .init(value: "静默", label: L("不打扰"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 工作流

    private var workflowSection: some View {
        LandingSection(title: L("后台工作流"), icon: "arrow.triangle.branch.and.merge", subtitle: L("你不打扰它,它不打扰你")) {
            LandingStepFlow(steps: [
                .init(title: L("空闲触发"), description: L("系统空闲时自动开始扫描项目问题。"), icon: "moon.zzz"),
                .init(title: L("汇总问题"), description: L("维护一份已检测问题的清单备用。")),
                .init(title: L("提示 LLM"), description: L("把已知问题的上下文作为提示提供给模型。")),
                .init(title: L("静默运行"), description: L("全程后台执行,不打断你的工作流。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "moon.zzz", tint: theme.warning,
                      title: L("空闲时扫描"),
                      description: L("系统空闲时自动扫描项目问题。")),
                .init(icon: "sparkles", tint: theme.primary,
                      title: L("AI 提示"),
                      description: L("向 LLM 提供关于已知问题的上下文提示。")),
                .init(icon: "list.bullet.rectangle", tint: theme.info,
                      title: L("问题追踪"),
                      description: L("维护已检测到的问题清单供参考。")),
                .init(icon: "gearshape.2", tint: theme.success,
                      title: L("后台处理"),
                      description: L("后台运行扫描,不干扰你的工作流。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        ProjectIssueScannerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
