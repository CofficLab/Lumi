import LumiUI
import SwiftUI

// MARK: - Manual View

/// 图片转 PDF 使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct ImageToPDFManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Image to PDF"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Image to PDF: converting images into single-page PDF files and exporting them."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Drop zone: drag image files onto 「Drag & drop image files here」, or click to browse; the file count is shown below.")),
                .init(L("Input list: selected images appear as rows, each with a remove button.")),
                .init(L("Action bar: the 「Add files」 and 「Convert」 buttons.")),
                .init(L("Output list: the 「PDFs」 section shows each produced PDF with its status and the 「Reveal in Finder」, 「Open」, and 「Remove」 buttons, plus 「Export to…」 and 「Clear」.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Image to PDF tab in the sidebar.")),
                .init(L("Drag image files into the drop zone, or click it to browse and select files.")),
                .init(L("Click 「Convert」; each image is converted into a single-page PDF.")),
                .init(L("Click 「Export to…」 and choose a folder to save all PDFs at once.")),
                .init(L("Use 「Reveal in Finder」 or 「Open」 on a row to locate or view a PDF.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Each image becomes a separate single-page PDF; conversion follows the order of the input list.")),
                .init(L("PDFs keep the original image size and orientation; images are not resized or compressed.")),
                .init(L("Supported formats include PNG, JPEG, HEIC, TIFF, BMP, and GIF.")),
                .init(L("Re-converting replaces the previous PDFs in the output list.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 拖放区示意
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                    lineMock(width: 80)
                    lineMock(width: 44)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(theme.appDivider, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 操作按钮示意
                HStack(spacing: 6) {
                    toolbarPill("plus")
                    buttonMock(filled: true)
                    Spacer(minLength: 0)
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                // ③ 输出列表示意
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(L("PDFs"))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Spacer(minLength: 0)
                        Text(L("Export to…"))
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                        Text(L("Clear"))
                            .font(.system(size: 8))
                            .foregroundColor(theme.textSecondary)
                    }
                    pdfRowMock()
                    pdfRowMock()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(3).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Drop zone"))
                    ManualFigureLegendItem(2, L("Action bar"))
                    ManualFigureLegendItem(3, L("Output list"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 输出行示意:缩略图 + 文件名/状态 + 操作按钮。
    private func pdfRowMock() -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 3) {
                lineMock(width: 64)
                lineMock(width: 30)
            }
            Spacer(minLength: 0)
            toolbarPill("eye", size: 8)
            toolbarPill("folder", size: 8)
            toolbarPill("trash", size: 8)
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 主操作按钮示意。
    private func buttonMock(filled: Bool) -> some View {
        lineMock(width: 40)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(filled ? theme.primary.opacity(0.75) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(filled ? Color.clear : theme.appDivider)
            )
    }

    /// 工具栏按钮示意。
    private func toolbarPill(_ systemImage: String, size: CGFloat = 9) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: size))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 7)
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
        ImageToPDFLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        ImageToPDFManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
