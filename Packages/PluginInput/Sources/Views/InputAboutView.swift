import LumiUI
import SwiftUI

/// 输入管理器插件关于视图 —— Landing 落地页。
struct InputAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "text.cursor",
            accent: theme.info,
            tagline: L("Manages the chat input area and text composition."),
            chips: [L("Input area"), L("Composition")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "text.cursor", tint: theme.info,
                      title: L("Chat Input"),
                      description: L("The main input area for composing messages.")),
                .init(icon: "keyboard", tint: theme.primary,
                      title: L("Text Composition"),
                      description: L("Structured composition of user text.")),
                .init(icon: "rectangle.3.group", tint: theme.success,
                      title: L("Input UI"),
                      description: L("A dedicated view container for the input surface."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "message",
                      title: L("Chat input bar"))
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
        InputAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
