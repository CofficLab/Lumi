import LumiUI
import SwiftUI

/// 原型设计插件关于视图 —— 以「对话生成原型 + 内嵌预览」为主轴的落地页。
struct PrototypeDesignerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            howItWorksSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "uiwindow.split.2x1",
            accent: theme.primary,
            tagline: L("About.Tagline"),
            chips: [
                L("About.Chip.HTML"),
                L("About.Chip.Interactive"),
                L("About.Chip.InlinePreview"),
                L("About.Chip.Iterate")
            ],
            metrics: [
                .init(value: "2", label: L("About.Metric.Tools")),
                .init(value: L("About.Metric.Chat"), label: L("About.Metric.DrivenBy")),
                .init(value: L("About.Metric.WebView"), label: L("About.Metric.PreviewIn"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("About.Section.Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "wand.and.stars", tint: theme.primary,
                      title: L("About.Feature.Generate"),
                      description: L("About.Feature.Generate.Description")),
                .init(icon: "slider.horizontal.3", tint: theme.info,
                      title: L("About.Feature.Refine"),
                      description: L("About.Feature.Refine.Description")),
                .init(icon: "play.rectangle", tint: theme.success,
                      title: L("About.Feature.Preview"),
                      description: L("About.Feature.Preview.Description")),
                .init(icon: "bubble.left.and.text.bubble.right", tint: theme.warning,
                      title: L("About.Feature.NoPanel"),
                      description: L("About.Feature.NoPanel.Description"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("About.Section.HowItWorks"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("About.Step.Enable"), description: L("About.Step.Enable.Description"), icon: "power"),
                .init(title: L("About.Step.Describe"), description: L("About.Step.Describe.Description"), icon: "text.bubble"),
                .init(title: L("About.Step.Preview"), description: L("About.Step.Preview.Description"), icon: "play.rectangle")
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PrototypeDesignerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        PrototypeDesignerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
