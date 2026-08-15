import LumiUI
import SwiftUI

/// 简历设计插件关于视图 —— Landing 落地页。
public struct ResumeAboutView: View {
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
            icon: "doc.badge.gearshape",
            accent: theme.primary,
            tagline: L("Agent-built HTML resumes with print-optimized PDF and PNG export."),
            chips: [L("HTML"), L("PDF"), L("PNG")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.text", tint: theme.primary,
                      title: L("HTML Resumes"),
                      description: L("Complete deterministic HTML documents, one page at a time.")),
                .init(icon: "printer", tint: theme.success,
                      title: L("Print Ready"),
                      description: L("Exact A4 or Letter pages with selectable text.")),
                .init(icon: "square.and.arrow.down", tint: theme.info,
                      title: L("PDF & PNG Export"),
                      description: L("Export print-ready PDFs and preview PNGs.")),
                .init(icon: "textformat.size", tint: theme.warning,
                      title: L("Template Library"),
                      description: L("Classic, modern, minimal or fully custom layouts.")),
                .init(icon: "photo", tint: theme.info,
                      title: L("Local Assets"),
                      description: L("Import a profile photo into the document.")),
                .init(icon: "checkmark.seal", tint: theme.success,
                      title: L("Lint & Preview"),
                      description: L("Overflow checks and rendered page previews."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "sidebar.left",
                      title: L("Resume tab in the sidebar")),
                .init(icon: "bubble.left.and.bubble.right",
                      title: L("Ask the agent to write a resume"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        ResumeLocalization.string(key)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        ResumeAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
