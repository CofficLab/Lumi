import LumiUI
import SwiftUI

/// 思维导图插件关于视图 —— Landing 落地页。
public struct MindMapAboutView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "brain.head.profile",
            accent: theme.info,
            tagline: L("A native SwiftUI mind map editor. Grow trees with agent tools in chat or edit directly on the canvas."),
            chips: [L("Canvas"), L("Agent tools"), L("Bilateral tree")],
            metrics: [
                .init(value: L("Project"), label: L("scope")),
                .init(value: L("JSON"), label: L("export"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.and.pencil", tint: theme.info,
                      title: L("Native Canvas"),
                      description: L("Click to select, click again to edit node text inline.")),
                .init(icon: "wand.and.stars", tint: theme.primary,
                      title: L("Agent Driven"),
                      description: L("Create and grow maps from natural language in chat.")),
                .init(icon: "arrow.triangle.branch", tint: theme.success,
                      title: L("Tidy Layout"),
                      description: L("Two-sided balanced tree layout that re-flows automatically.")),
                .init(icon: "square.stack.3d.down.right", tint: theme.warning,
                      title: L("Dual Scope Storage"),
                      description: L("Project (.lumi/mind-map) and app-wide scopes.")),
                .init(icon: "arrow.down.doc", tint: theme.primary,
                      title: L("Import & Export"),
                      description: L("Import outlines; export as Markdown or JSON.")),
                .init(icon: "arrow.up.arrow.down", tint: theme.info,
                      title: L("Reorganize"),
                      description: L("Move, collapse and prune nodes freely."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Mind Maps tab in the sidebar")),
                .init(icon: "bubble.left.and.bubble.right",
                      title: L("Ask the agent in chat"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        MindMapLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        MindMapAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
