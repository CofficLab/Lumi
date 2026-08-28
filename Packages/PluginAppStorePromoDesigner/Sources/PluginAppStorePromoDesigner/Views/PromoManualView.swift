import LumiUI
import SwiftUI

// MARK: - Manual View

/// App Store 宣传图设计器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct PromoManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("App Store Promo Designer"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of the App Store Promo Designer: creating, editing, localizing, and exporting promo screenshots."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Sidebar: the task list, grouped into In Project and In App.")),
                .init(L("Toolbar: language picker, display size picker, Preview / HTML Source switch, Refresh, and Export.")),
                .init(L("Preview: shows the image at the selected display size.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Creating a Promo Image"))
            ManualStepList(items: [
                .init(L("Open the promo designer tab in the sidebar.")),
                .init(L("Describe your app and what to highlight in the chat, e.g. \"a promo image for a coffee tracker, highlight the brew timer\".")),
                .init(L("Review the generated image in the preview.")),
            ])

            ManualSectionHeader(number: 4, title: L("Editing Content"))
            ManualBulletList(items: [
                .init(L("State changes in the conversation, such as copy, colors, or layout.")),
                .init(L("In Preview mode, right-click the headline or the screenshot area to draft an edit request for that block.")),
            ])
            blockEditFigure

            ManualSectionHeader(number: 5, title: L("Adding Languages"))
            ManualStepList(items: [
                .init(L("Choose Add Language from the language picker.")),
                .init(L("Ask the AI to translate and adapt the copy for the new language.")),
            ])

            ManualSectionHeader(number: 6, title: L("Exporting"))
            ManualStepList(items: [
                .init(L("Select a display size in the toolbar.")),
                .init(L("Click Export and choose a folder.")),
                .init(L("Images are exported as PNGs at the selected size, grouped into folders by language.")),
            ])
            ManualBulletList(items: [
                .init(L("Available sizes: iPhone 6.7\" (1290×2796), iPhone 6.5\" (1284×2778), iPhone 6.1\" / 5.8\" (1170×2532), iPad Pro 12.9\" (2048×2732), iPad Pro 11\" (1668×2388), and Desktop (1280×800).")),
            ])
            exportFigure

            ManualSectionHeader(number: 7, title: L("Storage"))
            ManualBulletList(items: [
                .init(L("In Project: stored with the current project and available only to it.")),
                .init(L("In App: stored in the app and available in every project.")),
            ])

            ManualSectionHeader(number: 8, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Ask the AI to review the image and apply its suggestions before exporting.")),
                .init(L("Product screenshots must be provided by you; ask the AI to import them.")),
                .init(L("Click Refresh in the toolbar if the list or preview looks out of date.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    // ① 侧边栏:任务列表示意
                    VStack(alignment: .leading, spacing: 7) {
                        groupLabel(L("In Project"))
                        taskRowMock()
                        taskRowMock()
                        groupLabel(L("In App"))
                        taskRowMock()
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(width: 122, height: 172, alignment: .topLeading)
                    .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                    Divider()

                    // 主区域:② 工具栏 + ③ 预览
                    VStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Spacer(minLength: 0)
                            toolbarPill("globe")
                            toolbarPill("rectangle")
                            segmentedMock()
                            toolbarPill("square.and.arrow.down")
                        }
                        .overlay(alignment: .top) { ManualFigureMarker(2).offset(y: -9) }

                        Spacer(minLength: 0)

                        phoneMock()

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 172)
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

    // MARK: - 图 2 右键点击区块即可修改

    private var blockEditFigure: some View {
        ManualFigure(caption: L("Figure 2: Right-click a block to edit it")) {
            HStack(spacing: 22) {
                // 预览示意:标题区块高亮
                VStack(spacing: 8) {
                    Text(PromoLocalization.string("APP"))
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.primary.opacity(0.75)))

                    Text("12345678")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.warning, lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "cursorarrow.click")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.warning)
                                .offset(x: 8, y: -10)
                        }

                    screenshotMock()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

                // 生成的修改请求
                VStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    lineMock(width: 84)
                    lineMock(width: 64)
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 图 3 按语言分组的导出结果

    private var exportFigure: some View {
        ManualFigure(caption: L("Figure 3: Exports grouped by language")) {
            VStack(alignment: .leading, spacing: 5) {
                treeRow(icon: "folder", text: "zh-Hans", mono: false, indent: 0)
                treeRow(icon: "doc", text: "01-hero-APP_IPHONE_67.png", mono: true, indent: 1)
                treeRow(icon: "folder", text: "en-US", mono: false, indent: 0)
                treeRow(icon: "doc", text: "01-hero-APP_IPHONE_67.png", mono: true, indent: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 示意简笔元素

    /// 侧边栏分组小标题。
    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundColor(theme.textSecondary)
    }

    /// 侧边栏任务行:堆叠图标 + 两根文字线。
    private func taskRowMock() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 8))
                .foregroundStyle(theme.textSecondary)
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
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(theme.appDivider)
            )
    }

    /// 「预览 / 源码」切换示意:两格相连的分段控件。
    private func segmentedMock() -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 16, height: 14)
            Rectangle().fill(Color.clear).frame(width: 16, height: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 宣传图预览示意:竖版卡片 = 眉标 + 标题两行 + 截图框。
    private func phoneMock() -> some View {
        VStack(spacing: 7) {
            lineMock(width: 22)
            VStack(spacing: 3) {
                lineMock(width: 64)
                lineMock(width: 48)
            }
            screenshotMock()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primary.opacity(0.1), theme.primarySecondary.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }

    /// 截图框示意。
    private func screenshotMock() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.06))
            Image(systemName: "photo")
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(width: 56, height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 导出目录树行。
    private func treeRow(icon: String, text: String, mono: Bool, indent: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
            Text(text)
                .font(.system(size: mono ? 9 : 10, design: mono ? .monospaced : .default))
                .foregroundColor(theme.textPrimary)
        }
        .padding(.leading, indent * 18)
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        PromoLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        PromoManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
