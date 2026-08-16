import LumiUI
import SwiftUI

private typealias L = ResumeDesignerLocalization

/// 简历设计插件关于视图 —— Landing 落地页。
struct DesignerAboutView: View {
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
            icon: "doc.badge.gearshape",
            accent: theme.primary,
            tagline: L.string("Agent-built HTML resumes with print-optimized PDF and PNG export."),
            chips: [L.string("HTML"), L.string("PDF"), L.string("PNG")]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L.string("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.text", tint: theme.primary,
                      title: L.string("HTML Resumes"),
                      description: L.string("Complete deterministic HTML documents, one page at a time.")),
                .init(icon: "printer", tint: theme.success,
                      title: L.string("Print Ready"),
                      description: L.string("Exact A4 or Letter pages with selectable text.")),
                .init(icon: "square.and.arrow.down", tint: theme.info,
                      title: L.string("PDF & PNG Export"),
                      description: L.string("Export print-ready PDFs and preview PNGs.")),
                .init(icon: "textformat.size", tint: theme.warning,
                      title: L.string("Template Library"),
                      description: L.string("Classic, modern, minimal or fully custom layouts.")),
                .init(icon: "photo", tint: theme.info,
                      title: L.string("Local Assets"),
                      description: L.string("Import a profile photo into the document.")),
                .init(icon: "checkmark.seal", tint: theme.success,
                      title: L.string("Lint & Preview"),
                      description: L.string("Overflow checks and rendered page previews."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L.string("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "sidebar.left",
                      title: L.string("Resume tab in the sidebar")),
                .init(icon: "bubble.left.and.bubble.right",
                      title: L.string("Ask the agent to write a resume"))
            ])
        }
        .landingAppear(delay: 0.1)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        DesignerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
