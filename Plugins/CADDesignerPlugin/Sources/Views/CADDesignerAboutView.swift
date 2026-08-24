import LumiUI
import SwiftUI

// MARK: - About View

/// CAD 设计器插件关于视图 —— 以产品落地页的形式介绍功能。
public struct CADDesignerAboutView: View {
    @Environment(\.locale) private var locale
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            aiToolsSection
            technicalSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "cube.transparent",
            accent: theme.primary,
            tagline: L("用 AI 辅助搭建铝型材结构:3D 视口拼装、自动生成 BOM、优化下料,从设计到出料一站完成。"),
            chips: [L("3D 视口"), L("铝型材库"), L("AI 设计")],
            metrics: [
                .init(value: "12", label: L("型材规格")),
                .init(value: "9", label: L("AI 工具")),
                .init(value: "PDF", label: L("导出格式"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 设计能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("设计能力"), icon: "square.stack.3d.up", subtitle: L("从拼装到出料的完整链路")) {
            LandingFeatureGrid(items: [
                .init(icon: "square.stack.3d.up", tint: theme.primary,
                      title: L("3D 视口"),
                      description: L("原生 3D 视口实时拼装与预览结构。")),
                .init(icon: "shippingbox", tint: theme.info,
                      title: L("元件库"),
                      description: L("内置欧标 20/30/40 系列铝型材(12 种规格)与支架、螺栓、滑块螺母、端盖、合页等连接件。")),
                .init(icon: "link", tint: theme.warning,
                      title: L("装配关系"),
                      description: L("以刚性、合页或螺栓连接定义元件关系,构建精确的装配结构。")),
                .init(icon: "list.clipboard", tint: theme.success,
                      title: L("BOM 生成"),
                      description: L("自动汇总相同型材与连接件,生成带数量与规格的物料清单。")),
                .init(icon: "scissors", tint: theme.error,
                      title: L("下料优化"),
                      description: L("采用首次适应递减算法优化切割方案,减少浪费与余料。")),
                .init(icon: "square.and.arrow.up", tint: theme.primary,
                      title: L("导入导出"),
                      description: L("视口渲染导出为 PNG 或 PDF,项目存取为 .cadproj(JSON)。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - AI 工具

    private var aiToolsSection: some View {
        LandingSection(title: L("可用的 AI 工具"), icon: "wand.and.stars", subtitle: L("由 Agent 调用,对话即可驱动设计")) {
            LandingFeatureGrid(items: [
                .init(icon: "folder.badge.plus", title: L("新建项目"), description: "cad_create_project"),
                .init(icon: "rectangle.on.rectangle", title: L("放置型材"), description: "cad_place_profile"),
                .init(icon: "slider.horizontal.3", title: L("更新属性"), description: "cad_update_profile"),
                .init(icon: "bolt", title: L("放置连接件"), description: "cad_place_connector"),
                .init(icon: "link", title: L("定义连接"), description: "cad_connect_components"),
                .init(icon: "list.clipboard", title: L("生成 BOM"), description: "cad_generate_bom"),
                .init(icon: "scissors", title: L("优化下料"), description: "cad_optimize_cutting"),
                .init(icon: "tray.and.arrow.down", title: L("保存项目"), description: "cad_save_project"),
                .init(icon: "tray.and.arrow.up", title: L("加载项目"), description: "cad_load_project")
            ], minColumnWidth: 170)
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 技术细节

    private var technicalSection: some View {
        LandingSection(title: L("技术细节"), icon: "wrench.and.screwdriver") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    techRow(L("3D 引擎"), L("SceneKit(macOS 原生)"))
                    AppDivider()
                    techRow(L("项目格式"), ".cadproj (JSON)")
                    AppDivider()
                    techRow(L("型材标准"), L("欧标 20/30/40 系列"))
                }
            }
        }
        .landingAppear(delay: 0.15)
    }

    private func techRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        CADDesignerLocalization.string(key, locale: locale)
    }
}

#Preview {
    ScrollView {
        CADDesignerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
