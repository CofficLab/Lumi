import LumiUI
import SwiftUI

/// 图片转 PDF 插件关于视图 —— 以「拖拽即转」为卖点的落地页。
struct ImageToPDFAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            capabilitiesSection
            howItWorksSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "photo.stack",
            accent: theme.info,
            tagline: L("把图片拖进来,瞬间变成保留原尺寸与方向的 PDF——单张或批量都行。"),
            chips: [L("拖拽即转"), L("批量"), L("保留原尺寸")],
            metrics: [
                .init(value: "1", label: L("拖拽动作")),
                .init(value: "批量", label: L("同时转换")),
                .init(value: "PDF", label: L("输出"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "arrow.down.doc",
            tint: theme.info,
            title: L("拖进来,就是 PDF"),
            message: L("每张图片各自成为一页 PDF,完整保留原始尺寸与朝向,无需任何配置。")
        ) {
            HStack(spacing: 6) {
                AppTag("PNG", style: .subtle)
                AppTag("JPG", style: .subtle)
                AppTag("HEIC", style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "doc.richtext", tint: theme.info,
                      title: L("图片转 PDF"),
                      description: L("将图片转为保留原尺寸与方向的单页 PDF。")),
                .init(icon: "square.stack.3d.up", tint: theme.warning,
                      title: L("批量转换"),
                      description: L("一次拖入多张图片,每张各自生成一份 PDF。")),
                .init(icon: "square.and.arrow.up", tint: theme.success,
                      title: L("统一导出"),
                      description: L("选择目录一次性导出全部 PDF,也可单独打开。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("拖入图片"), description: L("把一张或多张图片拖到面板。"), icon: "arrow.down.doc"),
                .init(title: L("自动转换"), description: L("每张图片按原尺寸生成对应的单页 PDF。")),
                .init(title: L("导出结果"), description: L("选择目录批量导出,或逐个打开。"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        ImageToPDFLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        ImageToPDFAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
