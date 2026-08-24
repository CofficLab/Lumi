import LumiUI
import SwiftUI

/// 思维导图插件关于视图 —— Landing 落地页。
struct MindMapAboutView: View {
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
            icon: "brain.head.profile",
            accent: theme.info,
            tagline: L("A native SwiftUI mind map editor. Grow trees with agent tools in chat or edit directly on the canvas.",
                       "原生 SwiftUI 思维导图编辑器。可在聊天中用 Agent 工具生长思维树，或直接在画布上编辑。"),
            chips: [L("Canvas", "画布"), L("Agent tools", "Agent 工具"), L("Bilateral tree", "双侧树")],
            metrics: [
                .init(value: L("Project", "项目内"), label: L("scope", "作用域")),
                .init(value: L("JSON", "JSON"), label: L("export", "导出"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities", "核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "square.and.pencil", tint: theme.info,
                      title: L("Native Canvas", "原生画布"),
                      description: L("Click to select, click again to edit node text inline.", "点击节点选中，再次点击原位编辑文字。")),
                .init(icon: "wand.and.stars", tint: theme.primary,
                      title: L("Agent Driven", "Agent 驱动"),
                      description: L("Create and grow maps from natural language in chat.", "在聊天中用自然语言创建与生长导图。")),
                .init(icon: "arrow.triangle.branch", tint: theme.success,
                      title: L("Tidy Layout", "整齐布局"),
                      description: L("Two-sided balanced tree layout that re-flows automatically.", "双侧平衡树布局，自动重排。")),
                .init(icon: "square.stack.3d.down.right", tint: theme.warning,
                      title: L("Dual Scope Storage", "双作用域存储"),
                      description: L("Project (.lumi/mind-map) and app-wide scopes.", "项目（.lumi/mind-map）与应用两个作用域。")),
                .init(icon: "arrow.down.doc", tint: theme.primary,
                      title: L("Import & Export", "导入与导出"),
                      description: L("Import outlines; export as Markdown or JSON.", "导入大纲；导出 Markdown 或 JSON。")),
                .init(icon: "arrow.up.arrow.down", tint: theme.info,
                      title: L("Reorganize", "重组结构"),
                      description: L("Move, collapse and prune nodes freely.", "自由移动、折叠与修剪节点。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It", "使用入口"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "sidebar.left",
                      title: L("Mind Maps tab in the sidebar", "侧边栏中的「思维导图」标签页")),
                .init(icon: "bubble.left.and.bubble.right",
                      title: L("Ask the agent in chat", "在聊天中让 Agent 创建导图"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ en: String, _ zh: String) -> String {
        MindMapLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        MindMapAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
