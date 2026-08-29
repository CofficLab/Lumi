import LumiUI
import SwiftUI

// MARK: - About View

/// App 图标设计器关于视图 —— 以「AI 辅助矢量设计」为卖点的落地页。
struct DesignerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            capabilitiesSection
            workflowSection
            outputSection
            storageSection
            shapesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "app.dashed",
            accent: theme.primary,
            tagline: L("Create app icons with precise vector shapes including rectangles, circles, capsules, triangles, lines, symbols, and text."),
            chips: [L("Vector Icon Design"), L("AI Operations"), L("Xcode Export")],
            metrics: [
                .init(value: "7+", label: "基础形状"),
                .init(value: "SVG", label: L("SVG Export")),
                .init(value: "Xcode", label: L("Xcode Export"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "wand.and.stars",
            tint: theme.primary,
            title: L("让 AI 帮你设计图标"),
            message: L("Let AI help generate icon presets, apply styling, and lint your designs for best practices.")
        ) {
            HStack(spacing: 6) {
                AppTag(L("生成预设"), style: .accent)
                AppTag(L("风格化"), style: .subtle)
                AppTag(L("Lint"), style: .subtle)
                AppTag(L("Review"), style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "rectangle.dashed", tint: theme.primary,
                      title: L("Vector Icon Design"),
                      description: L("Create app icons with precise vector shapes including rectangles, circles, capsules, triangles, lines, symbols, and text.")),
                .init(icon: "square.stack.3d.up", tint: theme.info,
                      title: L("图层管理"),
                      description: L("Build complex icons with multiple layers. Control opacity, shadows, blur effects, and transform properties for each layer.")),
                .init(icon: "paintpalette", tint: theme.warning,
                      title: L("丰富填充"),
                      description: L("Adjust layers: fill (solid or gradient), stroke, shadow, blur, opacity, and rotation.")),
                .init(icon: "square.and.arrow.up", tint: theme.success,
                      title: L("多格式导出"),
                      description: L("Export as Xcode AppIcon set or SVG")),
                .init(icon: "eye", tint: theme.info,
                      title: L("Preview"),
                      description: L("Preview your icon at multiple sizes")),
                .init(icon: "checkmark.shield", tint: theme.warning,
                      title: L("Lint"),
                      description: L("Check the icon and suggest improvements."))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 工作流程

    private var workflowSection: some View {
        LandingSection(title: "工作流程", icon: "arrow.triangle.branch.and.merge") {
            LandingStepFlow(steps: [
                .init(title: "创建或加载文档", description: L("Click + to create a new icon document, or select an existing one from the list."), icon: "doc.badge.plus"),
                .init(title: "描述并迭代", description: L("Ask the Agent to create or load an icon document."), icon: "bubble.left.and.bubble.right"),
                .init(title: "检查设计", description: L("Check the icon and suggest improvements."), icon: "checkmark.seal"),
                .init(title: "导出最终资源", description: L("Export as Xcode AppIcon set or SVG"), icon: "square.and.arrow.down")
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - 输出能力

    private var outputSection: some View {
        LandingSection(title: "输出与交付", icon: "square.and.arrow.up") {
            LandingFeatureGrid(items: [
                .init(icon: "curlybraces.square", tint: theme.info,
                      title: L("SVG Export"),
                      description: L("Export vector graphics in SVG format for web, documentation, or further editing in design tools.")),
                .init(icon: "app.dashed", tint: theme.success,
                      title: L("Xcode Export"),
                      description: L("Export an AppIcon.icon for macOS 15 and later")),
                .init(icon: "eye", tint: theme.primary,
                      title: L("Preview"),
                      description: L("Preview: shows the current icon with its size and layer count."))
            ], minColumnWidth: 180)
        }
        .landingAppear(delay: 0.2)
    }

    // MARK: - 存储

    private var storageSection: some View {
        LandingSection(title: L("Storage"), icon: "externaldrive") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "folder", title: L("Project documents: stored with the current project and available only to it.")),
                .init(icon: "app.badge", title: L("Shared documents: stored in the app and available in every project.")),
                .init(icon: "scope", title: L("Current storage scope"))
            ])
        }
        .landingAppear(delay: 0.25)
    }

    // MARK: - 支持形状

    private var shapesSection: some View {
        LandingSection(title: "支持的形状", icon: "circle.hexagongrid") {
            LandingInventory(tint: theme.primary, items: [
                .init(icon: "rectangle", title: L("矩形")),
                .init(icon: "circle", title: L("圆形")),
                .init(icon: "capsule", title: L("胶囊")),
                .init(icon: "triangle", title: L("三角形")),
                .init(icon: "line.diagonal", title: L("线条")),
                .init(icon: "symbol", title: L("符号")),
                .init(icon: "textformat", title: L("文本"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        AppIconDesignerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        DesignerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
