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
            shapesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "app.dashed",
            accent: theme.primary,
            tagline: L("用矢量图层精确设计应用图标,导出 SVG、PNG,甚至直接产出 Xcode 所需的 AppIcon。"),
            chips: [L("矢量设计"), L("图层"), L("AI 辅助")],
            metrics: [
                .init(value: "7+", label: L("基础形状")),
                .init(value: "SVG/PNG", label: L("导出")),
                .init(value: "Xcode", label: L("直接产出"))
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
            message: L("AI 可生成图标预设、套用风格,并对你的设计进行最佳实践检查。")
        ) {
            HStack(spacing: 6) {
                AppTag(L("生成预设"), style: .accent)
                AppTag(L("风格化"), style: .subtle)
                AppTag(L("Lint"), style: .subtle)
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
                      title: L("矢量图标设计"),
                      description: L("矩形、圆形、胶囊、三角、线条、符号与文本等精确矢量形状。")),
                .init(icon: "square.stack.3d.up", tint: theme.info,
                      title: L("图层管理"),
                      description: L("多图层构建复杂图标,逐层控制透明度、阴影、模糊与变换。")),
                .init(icon: "paintpalette", tint: theme.warning,
                      title: L("丰富填充"),
                      description: L("纯色、线性或径向渐变填充,自定义描边宽度与颜色。")),
                .init(icon: "square.and.arrow.up", tint: theme.success,
                      title: L("多格式导出"),
                      description: L("导出 SVG 用于网页与文档,或导出 Xcode 所需的 AppIcon.icon。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 支持形状

    private var shapesSection: some View {
        LandingSection(title: L("支持的形状"), icon: "circle.hexagongrid") {
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
