import LumiUI
import SwiftUI

// MARK: - Manual View

/// PDF 工具使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct BookletMakerManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("PDF Tools"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of PDF Tools: making booklets from PDF files and splitting PDF files."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Current PDF: the drop area on the left; drop a PDF here or click to choose one.")),
                .init(L("Toolbar: switches between the Booklet Maker and Split PDF tools.")),
                .init(L("Tool pane: shows the options of the selected tool and its action button.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Making a Booklet"))
            ManualStepList(items: [
                .init(L("Drop an A4 PDF into the Current PDF area, or click to choose one.")),
                .init(L("Choose the output paper size and the layout, such as Booklet Fold or Simple Pair.")),
                .init(L("Adjust the margins, gutter, blank-page padding, and cut marks as needed.")),
                .init(L("Click Export Booklet PDF and choose where to save.")),
            ])

            ManualSectionHeader(number: 4, title: L("Splitting a PDF"))
            ManualStepList(items: [
                .init(L("Switch to the Split PDF tool in the toolbar.")),
                .init(L("Drop a PDF into the Current PDF area, or click to choose one.")),
                .init(L("Enter the cut points as page numbers, e.g. \"20, 50, 80\", and the output name.")),
                .init(L("Review the page grid and the split result.")),
            ])

            ManualSectionHeader(number: 5, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Only A4 PDF files are supported.")),
                .init(L("Booklet pages are reordered for folding and binding; print a test sheet first.")),
                .init(L("Choose a new output name to avoid overwriting an existing file.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    // ② 工具切换
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 58, height: 16)
                        Rectangle().fill(Color.clear).frame(width: 46, height: 16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.appDivider)
                    )
                    .overlay(alignment: .top) { ManualFigureMarker(2).offset(y: -9) }

                    HStack(spacing: 0) {
                        // ① 当前 PDF 放置区
                        VStack(spacing: 7) {
                            Image(systemName: "doc")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.textSecondary)
                            lineMock(width: 44)
                            lineMock(width: 60)
                        }
                        .padding(10)
                        .frame(width: 120, height: 130)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(theme.appDivider, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                        .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                        Divider()

                        // ③ 工具设置面板
                        VStack(alignment: .leading, spacing: 8) {
                            fieldRowMock()
                            fieldRowMock()
                            fieldRowMock()
                            Spacer(minLength: 0)
                            HStack {
                                Spacer(minLength: 0)
                                actionPillMock()
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: 130)
                        .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }
                    }
                }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Current PDF"))
                    ManualFigureLegendItem(2, L("Toolbar"))
                    ManualFigureLegendItem(3, L("Tool Settings"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 设置面板字段行示意。
    private func fieldRowMock() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            lineMock(width: 36)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 104, height: 13)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
        }
    }

    /// 操作按钮示意。
    private func actionPillMock() -> some View {
        Image(systemName: "square.and.arrow.down")
            .font(.system(size: 9))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.appDivider)
            )
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        BookletLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        BookletMakerManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
