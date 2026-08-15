import LumiUI
import SwiftUI

// MARK: - Manual View

/// App 图标设计器说明书 —— 面向用户的使用指南,告诉用户「怎么用」,
/// 不展示实现细节。通过 `pluginManualView` 暴露,由设置-通用的
/// 「说明书」分区列出并在此处之外(sheet)阅读。
struct DesignerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            stepsSection
            askSection
            storageSection
            tipsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "app.dashed",
            accent: theme.primary,
            tagline: L("Design app icons by chatting with AI."),
            chips: [L("Chat to Design"), L("Live Preview"), L("Export Anytime")],
            metrics: [
                .init(value: "5", label: L("Built-in styles")),
                .init(value: "SVG · Xcode", label: L("Export formats"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 快速上手

    private var stepsSection: some View {
        LandingSection(title: L("Getting Started"), icon: "figure.walk") {
            LandingStepFlow(steps: [
                .init(
                    title: L("Open App Icon Designer"),
                    description: L("Select the App Icon Designer tab in the sidebar; your icon documents are listed on the left."),
                    icon: "sidebar.left"
                ),
                .init(
                    title: L("Create or open an icon"),
                    description: L("Click + for a blank icon, pick one from the list, or simply ask the AI to create one for you."),
                    icon: "plus.square"
                ),
                .init(
                    title: L("Describe the icon you want"),
                    description: L("Tell the AI what you have in mind, such as \"a blue gradient icon with a coffee cup\", or ask for a ready-made style."),
                    icon: "message.fill"
                ),
                .init(
                    title: L("Refine as you chat"),
                    description: L("Ask the AI to change the background, tweak a shape, or fine-tune colors and shadows until the preview looks right."),
                    icon: "slider.horizontal.3"
                ),
                .init(
                    title: L("Export your icon"),
                    description: L("When the preview looks good, click Export SVG or Export Xcode Icon and choose where to save it."),
                    icon: "square.and.arrow.up"
                ),
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 你可以让 AI 做什么

    private var askSection: some View {
        LandingSection(title: L("What You Can Ask"), icon: "bubble.left.and.bubble.right") {
            LandingFeatureGrid(items: [
                .init(icon: "paintbrush.pointed", tint: theme.primary,
                      title: L("Start from a style"),
                      description: L("Start from a built-in style, then ask for changes until it fits your app.")),
                .init(icon: "square.on.square.dashed", tint: theme.info,
                      title: L("Draw with shapes"),
                      description: L("Combine rectangles, circles, capsules, triangles, lines, symbols and text.")),
                .init(icon: "slider.horizontal.2.square", tint: theme.warning,
                      title: L("Adjust every detail"),
                      description: L("Solid or gradient fills, strokes, shadows, blur and transparency, layer by layer.")),
                .init(icon: "checkmark.seal", tint: theme.success,
                      title: L("Ask for a review"),
                      description: L("Before exporting, ask the AI to check your icon and suggest improvements.")),
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 图标保存在哪里

    private var storageSection: some View {
        LandingSection(title: L("Where Icons Are Stored"), icon: "archivebox") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "folder",
                      title: L("Project icons"),
                      description: L("Kept with the current project, so each project keeps its own set of icons.")),
                .init(icon: "app.badge",
                      title: L("Shared icons"),
                      description: L("Always available, no matter which project is open — handy for icons you reuse.")),
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - 小贴士

    private var tipsSection: some View {
        LandingSection(title: L("Tips"), icon: "lightbulb") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "ruler",
                      title: L("Sized for Xcode"),
                      description: L("New icons start at 1024 × 1024, the size Xcode expects.")),
                .init(icon: "rectangle.and.text.magnifyingglass",
                      title: L("Delete a document"),
                      description: L("Right-click a document in the list to delete it.")),
                .init(icon: "mappin.and.ellipse",
                      title: L("Find your exports"),
                      description: L("The most recent export location is shown below the preview.")),
            ])
        }
        .landingAppear(delay: 0.2)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        AppIconDesignerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        DesignerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
