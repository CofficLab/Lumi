import SwiftUI

// MARK: - Sheet Preview View

/// 「装订前」示意图：左侧为张数 tab（第一张 … 第四张），
/// 右侧显示选中那张纸的实际拼版内容（横向纸张上并排的左右两页）。
struct SheetPreviewView: View {
    let document: CurrentPDFDocument
    let settings: BookletSettings

    /// 当前选中的物理纸张（0-based）
    @State private var selectedSheet: Int = 0

    /// 根据当前设置计算出的输出纸张序列
    private var sheets: [PhysicalSheet] {
        BookletLayoutEngine.buildPhysicalSheets(inputPageCount: document.pageCount,
                                                settings: settings)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 12) {
                // 左侧：张数 tab
                sheetTabs
                    .frame(width: max(64, geo.size.width * 0.18))

                // 右侧：选中纸张的实际页面内容
                sheetContent(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: sheets.count) { _, count in
            if selectedSheet >= count { selectedSheet = max(0, count - 1) }
        }
    }

    // MARK: - Left Tabs

    private var sheetTabs: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(sheets.enumerated()), id: \.element.index) { index, _ in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSheet = index
                    }
                } label: {
                    Text(sheetTitle(index))
                        .font(.system(size: 11, weight: selectedSheet == index ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedSheet == index
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.secondary.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedSheet == index
                                        ? Color.accentColor
                                        : Color.clear,
                                        lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedSheet == index ? .accentColor : .primary)
            }
            Spacer()
        }
    }

    private func sheetTitle(_ index: Int) -> String {
        BookletLocalization.string("Sheet %lld", Int64(index + 1))
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(in size: CGSize) -> some View {
        if sheets.indices.contains(selectedSheet) {
            let physicalSheet = sheets[selectedSheet]
            VStack(spacing: 6) {
                outputSideView(physicalSheet.front)
                if let back = physicalSheet.back {
                    outputSideView(back)
                }
            }
        } else {
            Color.clear
        }
    }

    private func pairCaption(_ sheet: OutputSheet) -> String {
        BookletLocalization.string("Pages %lld + %lld",
                                   Int64(sheet.leftPage),
                                   Int64(sheet.rightPage))
    }

    private func outputSideView(_ outputSide: OutputSheet) -> some View {
        VStack(spacing: 3) {
            Text(outputSide.side == .front
                 ? BookletLocalization.string("Front")
                 : BookletLocalization.string("Back"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            OutputSheetView(
                sheet: outputSide,
                document: document,
                settings: settings
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(pairCaption(outputSide))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Output Sheet View

/// 单个打印面（横向）：按设置的边距/装订线摆放左右两个故事页。
struct OutputSheetView: View {
    let sheet: OutputSheet
    let document: CurrentPDFDocument
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            // 横向纸张比例：长边为宽
            let paperAspect = settings.outputPaper.widthMM / settings.outputPaper.heightMM
            let paperWidth = min(geo.size.width, geo.size.height / paperAspect)
            let paperHeight = paperWidth * paperAspect

            // 边距与装订线按纸张宽度等比缩放
            let unit = paperWidth / settings.outputPaper.heightMM  // 1mm 对应的显示点数
            let margin = max(1.5, settings.marginMM * unit)
            let gutter = max(1, settings.gutterMM * unit)

            let contentHeight = paperHeight - 2 * margin
            let pageWidth = (paperWidth - 2 * margin - gutter) / 2

            ZStack {
                // 纸张背景
                FixedWhitePaperSurface()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .frame(width: paperWidth, height: paperHeight)

                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.22), lineWidth: 1)
                    .frame(width: paperWidth, height: paperHeight)

                // 边距区域（淡色提示）
                if settings.marginMM > 0.5 {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.accentColor.opacity(0.25),
                                style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .frame(width: paperWidth - 2 * margin,
                               height: paperHeight - 2 * margin)
                }

                // 左右两个故事页
                HStack(spacing: gutter) {
                    sheetPage(sheet.leftPage, height: contentHeight, maxWidth: pageWidth)
                    sheetPage(sheet.rightPage, height: contentHeight, maxWidth: pageWidth)
                }
                .frame(width: paperWidth - 2 * margin, height: contentHeight)

                // 中线：书本折叠为折叠虚线，简单并排为分割线
                centerLine(paperHeight: paperHeight, margin: margin)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// 单个故事页；页码 0 表示空白页
    @ViewBuilder
    private func sheetPage(_ pageNumber: Int, height: CGFloat, maxWidth: CGFloat) -> some View {
        let pageAspect = document.pageAspectRatio
        let h = min(height, maxWidth / pageAspect)

        if pageNumber > 0 {
            PDFDocumentPageView(
                documentURL: document.url,
                pageNumber: pageNumber
            )
                .frame(width: h * pageAspect, height: h)
        } else {
            FixedWhitePaperSurface()
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.black.opacity(0.16), lineWidth: 1)
                )
                .frame(width: h * pageAspect, height: h)
        }
    }

    @ViewBuilder
    private func centerLine(paperHeight: CGFloat, margin: CGFloat) -> some View {
        switch settings.layout {
        case .bookletFold:
            // 折叠虚线
            Rectangle()
                .fill(Color.clear)
                .frame(width: 1, height: paperHeight - 2 * margin)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundColor(.accentColor.opacity(0.6))
                )
        case .simplePair:
            Rectangle()
                .fill(Color.black.opacity(0.22))
                .frame(width: 1, height: paperHeight - 2 * margin)
        }
    }
}

// MARK: - Preview

#Preview("Sheet Preview - Booklet Fold") {
    SheetPreviewView(
        document: try! DemoPDFProvider.makeDocument(),
        settings: BookletSettings()
    )
        .frame(width: 480, height: 260)
        .padding()
}

#Preview("Sheet Preview - Simple Pair") {
    SheetPreviewView(
        document: try! DemoPDFProvider.makeDocument(),
        settings: BookletSettings(layout: .simplePair)
    )
        .frame(width: 480, height: 260)
        .padding()
}
