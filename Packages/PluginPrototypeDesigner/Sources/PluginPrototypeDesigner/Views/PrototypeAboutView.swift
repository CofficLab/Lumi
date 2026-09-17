import LumiUI
import SwiftUI

/// 原型设计器关于视图 —— Landing 落地页。
public struct PrototypeAboutView: View {
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
            icon: "rectangle.on.rectangle.angled",
            accent: theme.primary,
            tagline: L("Chat with the Agent to sketch product prototypes as connected HTML screens."),
            chips: [L("Wireframe"), L("Hi-Fi"), L("HTML")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "text.bubble", tint: theme.primary,
                      title: L("Describe a Screen"),
                      description: L("Describe the screen in words and the Agent writes the layout for you.")),
                .init(icon: "arrow.turn.down.right", tint: theme.info,
                      title: L("Connected Screens"),
                      description: L("Screens link to each other so you can read the flow, not just single pictures.")),
                .init(icon: "ruler", tint: theme.success,
                      title: L("Exact Device Canvas"),
                      description: L("Every screen renders on a real device canvas with exact pixel export.")),
                .init(icon: "arrow.clockwise", tint: theme.warning,
                      title: L("Preview and Iterate"),
                      description: L("The Agent inspects each render and refines the layout in the conversation."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "sidebar.left",
                      title: L("Prototypes tab in the sidebar"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PrototypeLocalization.string(key)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        PrototypeAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
