import SwiftUI

// MARK: - Input Diagram

/// 输入示意图：显示原始 PDF 页面（两页 A4 并排）
struct InputDiagram: View {
    let paperSize: PaperSize

    var body: some View {
        GeometryReader { geo in
            let pageHeight = geo.size.height - 4
            let pageWidth = pageHeight * (210.0 / 297.0)  // A4 比例
            let spacing = min(8, (geo.size.width - 2 * pageWidth) / 2)

            HStack(spacing: spacing) {
                // 第一页（A4）
                A4PaperView(pageNumber: 1, showContent: true, height: pageHeight)
                    .frame(width: pageWidth)

                // 第二页（A4）
                A4PaperView(pageNumber: 2, showContent: true, height: pageHeight)
                    .frame(width: pageWidth)
            }
        }
    }
}

// MARK: - Preview

#Preview("Input Diagram") {
    InputDiagram(paperSize: .a4)
        .frame(width: 200, height: 127)
        .padding()
}
