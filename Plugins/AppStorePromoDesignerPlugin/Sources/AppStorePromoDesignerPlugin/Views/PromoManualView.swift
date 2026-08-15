import LumiUI
import SwiftUI

// MARK: - Manual View

/// App Store 宣传图设计器说明书 —— 面向用户的使用指南,告诉用户「怎么用」,
/// 不展示实现细节。通过 `pluginManualView` 暴露,由设置-通用的
/// 「说明书」分区列出并在此处之外(sheet)阅读。
struct PromoManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            stepsSection
            blockEditSpotlight
            askSection
            storageSection
            tipsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "photo.artframe",
            accent: theme.primary,
            tagline: L("Ask AI to design App Store promo screenshots for your app."),
            chips: [L("Chat to Create"), L("Multi-language"), L("Exact App Store Sizes")],
            metrics: [
                .init(value: "17", label: L("Languages")),
                .init(value: "7", label: L("App Store sizes"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 快速上手

    private var stepsSection: some View {
        LandingSection(title: L("Getting Started"), icon: "figure.walk") {
            LandingStepFlow(steps: [
                .init(
                    title: L("Open the Promo Designer"),
                    description: L("Select the promo designer tab in the sidebar; your tasks are listed on the left."),
                    icon: "sidebar.left"
                ),
                .init(
                    title: L("Ask the AI to create one"),
                    description: L("Describe your app and what to highlight, for example \"a promo image for a coffee tracker, highlight the brew timer\"."),
                    icon: "message.fill"
                ),
                .init(
                    title: L("Preview and refine"),
                    description: L("Toggle Preview / HTML Source in the toolbar, and ask the AI to change the copy, colors or layout until it looks right."),
                    icon: "slider.horizontal.3"
                ),
                .init(
                    title: L("Add more languages"),
                    description: L("Use the language picker to add a language version, then ask the AI to translate and adapt the text."),
                    icon: "globe"
                ),
                .init(
                    title: L("Export for App Store"),
                    description: L("Click Export and choose a folder; every image is saved as App Store-ready PNGs, grouped by language."),
                    icon: "square.and.arrow.up"
                ),
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 右键改区块

    private var blockEditSpotlight: some View {
        LandingSpotlight(
            icon: "hand.tap",
            tint: theme.primary,
            title: L("Right-click to tweak a block"),
            message: L("In Preview mode, right-click the headline or the screenshot area to instantly draft an edit request in chat.")
        )
        .landingAppear(delay: 0.1)
    }

    // MARK: - 你可以让 AI 做什么

    private var askSection: some View {
        LandingSection(title: L("What You Can Ask"), icon: "bubble.left.and.bubble.right") {
            LandingFeatureGrid(items: [
                .init(icon: "wand.and.stars", tint: theme.primary,
                      title: L("Design from scratch"),
                      description: L("Describe your app and its best features; the AI builds the layout for you.")),
                .init(icon: "photo.on.rectangle.angled", tint: theme.info,
                      title: L("Use your screenshots"),
                      description: L("Ask the AI to place your own screenshots into the image.")),
                .init(icon: "globe", tint: theme.warning,
                      title: L("Localize versions"),
                      description: L("Add a language and ask the AI to translate and adapt the copy.")),
                .init(icon: "checkmark.seal", tint: theme.success,
                      title: L("Get a design review"),
                      description: L("Before exporting, ask the AI to critique the design and suggest improvements.")),
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - 任务保存在哪里

    private var storageSection: some View {
        LandingSection(title: L("Where Tasks Are Stored"), icon: "archivebox") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "folder",
                      title: L("Project tasks"),
                      description: L("Kept with the current project, so each project keeps its own promo images.")),
                .init(icon: "app.badge",
                      title: L("Shared tasks"),
                      description: L("Always available, no matter which project is open.")),
            ])
        }
        .landingAppear(delay: 0.2)
    }

    // MARK: - 小贴士

    private var tipsSection: some View {
        LandingSection(title: L("Tips"), icon: "lightbulb") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "rectangle.on.rectangle.angle",
                      title: L("Pick the right size"),
                      description: L("Use the display picker to preview and export for iPhone, iPad or Desktop.")),
                .init(icon: "folder.badge.gearshape",
                      title: L("Find your exports"),
                      description: L("Exports are grouped into folders by language, ready to upload.")),
                .init(icon: "arrow.clockwise",
                      title: L("Refresh to see the latest"),
                      description: L("Click Refresh if a list or preview looks out of date.")),
            ])
        }
        .landingAppear(delay: 0.25)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PromoLocalization.string(key)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        PromoManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
