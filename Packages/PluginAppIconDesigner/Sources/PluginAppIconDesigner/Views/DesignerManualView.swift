import LumiUI
import SwiftUI

// MARK: - Manual View

/// App 图标设计器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct DesignerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("AppIconDesigner Name"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the App Icon Designer: creating, editing, and exporting app icons."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: the icon document list, grouped into project documents and shared documents.")),
                .init(L("Preview: shows the current icon with its size and layer count.")),
                .init(L("Toolbar: provides the Export SVG and Export Xcode Icon buttons.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the App Icon Designer tab in the sidebar.")),
                .init(L("Click + to create a new icon document, or select an existing one from the list.")),
                .init(L("Describe what you need in the chat, and the AI will draw and revise the icon, e.g. \"a blue gradient background with a coffee cup symbol\".")),
                .init(L("To make changes, state them in the conversation, e.g. \"change the background to green\".")),
                .init(L("When the preview is correct, click Export SVG or Export Xcode Icon and choose where to save.")),
            ])
            chatFigure

            ManualSectionHeader(number: 4, title: L("AI Operations"))
            ManualBulletList(items: [
                .init(L("Create icons and apply built-in styles.")),
                .init(L("Add and edit shapes: rectangle, circle, capsule, triangle, line, symbol, and text.")),
                .init(L("Adjust layers: fill (solid or gradient), stroke, shadow, blur, opacity, and rotation.")),
                .init(L("Check the icon and suggest improvements.")),
            ])

            ManualSectionHeader(number: 5, title: L("Storage"))
            ManualBulletList(items: [
                .init(L("Project documents: stored with the current project and available only to it.")),
                .init(L("Shared documents: stored in the app and available in every project.")),
            ])
            storageFigure

            ManualSectionHeader(number: 6, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("New icons default to 1024 × 1024.")),
                .init(L("Right-click a document in the list to delete it.")),
                .init(L("The most recent export location is shown below the preview.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏:文档列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("Project"))
                        docRowMock()
                        docRowMock()
                        groupLabel(L("Shared"))
                        docRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 122, height: 148, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // 主区域:② 工具栏 + ③ 预览
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            toolbarPill("square.and.arrow.down")
                            toolbarPill("app.dashed")
                        }
                        .overlay(alignment: .top) { ManualFigureMarker(2).offset(y: -9) }

                        iconThumbMock(size: 74)

                        Text("1024 × 1024")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 148)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Sidebar"))
                    ManualFigureLegendItem(2, L("Toolbar"))
                    ManualFigureLegendItem(3, L("Preview"))
                }
            }
        }
    }

    // MARK: - 图 2 在对话中描述需求

    private var chatFigure: some View {
        ManualFigure(caption: L("Figure 2: Describe the icon in the conversation")) {
            HStack(spacing: 18) {
                // 用户消息气泡
                HStack {
                    Spacer(minLength: 12)
                    Text(L("Blue gradient with a coffee cup"))
                        .font(.system(size: 10))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.07))
                        )
                }
                .frame(width: 190)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)

                // 生成的图标
                iconThumbMock(size: 58)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 图 3 文档分组

    private var storageFigure: some View {
        ManualFigure(caption: L("Figure 3: Document grouping")) {
            HStack(spacing: 14) {
                storageCard(L("Project"), icon: "folder", thumbCount: 2)
                storageCard(L("Shared"), icon: "app.badge", thumbCount: 3)
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 侧边栏文档行:缩略图 + 两根文字线。
    private func docRowMock() -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 44)
                lineMock(width: 28)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
            )
    }

    /// 图标预览示意:渐变圆角方块 + 符号。
    private func iconThumbMock(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primary.opacity(0.75), theme.info.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: size * 0.42))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    /// 存储分组卡片示意:标题 + 一排图标缩略图。
    private func storageCard(_ title: String, icon: String, thumbCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
            }

            HStack(spacing: 6) {
                ForEach(0..<thumbCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        AppIconDesignerLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        DesignerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
