import LumiUI
import SwiftUI

/// 故事写作插件关于视图 —— 以「双栏工作区 + AI 协作」为主轴的落地页。
struct StoryWriterAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            workflowSection
            capabilitiesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "book.closed.fill",
            accent: theme.warning,
            tagline: L("一个为长篇创作准备的双栏工作区:分章管理、AI 协作续写、Markdown 进出,专注把故事写完。"),
            chips: [L("章节管理"), L("AI 续写"), L("Markdown")],
            metrics: [
                .init(value: "12", label: L("AI 工具")),
                .init(value: "双栏", label: L("工作区")),
                .init(value: ".md", label: L("导入导出"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "rectangle.split.2x1",
            tint: theme.warning,
            title: L("左边大纲,右边正文"),
            message: L("双栏布局让你一边掌握整本书的结构,一边专注当前章节的写作。")
        ) {
            HStack(spacing: 6) {
                AppTag(L("大纲侧栏"), style: .subtle)
                AppTag(L("分章节"), style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 写作流程

    private var workflowSection: some View {
        LandingSection(title: L("写作流程"), icon: "arrow.triangle.branch.and.merge") {
            LandingStepFlow(steps: [
                .init(title: L("创建故事"), description: L("新建一个故事作品,设定整体框架。"), icon: "book.badge.plus"),
                .init(title: L("规划章节"), description: L("在大纲侧栏里拆分并排列章节。")),
                .init(title: L("AI 协作续写"), description: L("让 AI 工具辅助扩写、改写或润色。")),
                .init(title: L("导入导出"), description: L("用 Markdown 自由迁入迁出,不锁数据。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "list.bullet.rectangle.portrait", tint: theme.warning,
                      title: L("分章管理"),
                      description: L("按章节组织故事,轻松切换与重组。")),
                .init(icon: "sparkles", tint: theme.primary,
                      title: L("AI 写作工具"),
                      description: L("12 个 Agent 工具辅助扩写、改写与润色。")),
                .init(icon: "sidebar.left", tint: theme.info,
                      title: L("大纲侧栏"),
                      description: L("随时纵览全书结构,快速跳转章节。")),
                .init(icon: "doc.badge.gearshape", tint: theme.success,
                      title: L("Markdown 进出"),
                      description: L("支持 Markdown 导入与导出,数据不绑定。"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        StoryWriterAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
