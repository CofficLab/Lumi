import SwiftUI

// MARK: - Output Diagram

/// 输出示意图：显示两页内容如何合并到一张横向 A4 上。
/// 根据设置动态显示边距、间距、裁切标记等。
struct OutputDiagram: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            // OutputDiagram 位于 A4PaperView 的内容区域内，这里直接使用全部可用空间。
            let contentWidth = geo.size.width
            let contentHeight = geo.size.height

            // 根据设置计算边距和间距的显示比例
            let marginRatio = settings.marginMM / 30.0  // 最大 30mm 作为参考
            let gutterRatio = settings.gutterMM / 30.0

            let marginDisplay = max(2, min(20, contentWidth * marginRatio * 0.15))
            let gutterDisplay = max(1, min(15, contentWidth * gutterRatio * 0.1))

            // 外层 A4 会整体旋转 90°，因此内部需要先上下排列两个横向页面；
            // 旋转后它们才会成为左右排列、方向正常的两个竖向页面。
            let pageHeight = max(1, contentWidth - 2 * marginDisplay)
            let pageWidth = pageHeight * (210.0 / 297.0)

            ZStack {
                // 边距区域（用淡色表示）
                if marginDisplay > 2 {
                    // 左边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: marginDisplay)
                        .position(x: marginDisplay / 2, y: contentHeight / 2)

                    // 右边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: marginDisplay)
                        .position(x: contentWidth - marginDisplay / 2, y: contentHeight / 2)

                    // 上边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(height: marginDisplay)
                        .position(x: contentWidth / 2, y: marginDisplay / 2)

                    // 下边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(height: marginDisplay)
                        .position(x: contentWidth / 2, y: contentHeight - marginDisplay / 2)
                }

                // 旋转前上下排列，旋转后左右排列。
                VStack(spacing: gutterDisplay) {
                    outputPageView(pageNumber: 1, height: pageHeight)
                        .frame(width: pageHeight, height: pageWidth)

                    outputPageView(pageNumber: 2, height: pageHeight)
                        .frame(width: pageHeight, height: pageWidth)
                }
                .frame(width: pageHeight, height: pageWidth * 2 + gutterDisplay)
                .position(x: contentWidth / 2, y: contentHeight / 2)

                // 装订线（gutter）区域显示
                if gutterDisplay > 2 && settings.layout == .bookletFold {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: contentWidth - 2 * marginDisplay, height: gutterDisplay)
                        .position(x: contentWidth / 2, y: contentHeight / 2)

                    // 折叠虚线
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: contentWidth - 2 * marginDisplay, height: 1)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundColor(.accentColor.opacity(0.6))
                        )
                        .position(x: contentWidth / 2, y: contentHeight / 2)
                } else if settings.layout == .simplePair {
                    // Simple Pair 模式下显示分割线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: contentWidth - 2 * marginDisplay, height: 1)
                        .position(x: contentWidth / 2, y: contentHeight / 2)
                }

                // 裁切标记
                if settings.addCutMarks {
                    CutMarksView(margin: marginDisplay, gutter: gutterDisplay, showGutter: settings.layout == .bookletFold)
                        .rotationEffect(.degrees(90))
                }
            }
            .frame(width: contentWidth, height: contentHeight)
        }
    }

    /// 根据输出纸张大小返回对应的纸张视图
    @ViewBuilder
    private func outputPageView(pageNumber: Int?, height: CGFloat) -> some View {
        // 保持原始 A4 的纵横比，并显示与上方输入页面一致的示例文字。
        A4PaperView(pageNumber: pageNumber, showContent: true, height: height)
            // 抵消外层横向 A4 的旋转，保证小页面文字保持正常方向。
            .rotationEffect(.degrees(90))
    }

    private var outputLabel: String {
        let paper = settings.outputPaper.displayName
        switch settings.layout {
        case .bookletFold:
            return "\(paper) (2×)"
        case .simplePair:
            return "\(paper) (2 pages)"
        }
    }
}

// MARK: - Output Diagram Container

/// 输出示意图容器：复用 A4PaperView，旋转后作为横向 A4 输出纸张。
struct OutputDiagramContainer: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            // 旋转前是竖向 A4；旋转后尺寸正好等于上方单个 A4 的横向尺寸。
            let paperHeight = geo.size.width

            A4PaperView(pageNumber: nil, height: paperHeight) {
                OutputDiagram(settings: settings)
            }
            .rotationEffect(.degrees(-90))
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

// MARK: - Preview

#Preview("Output Diagram - A4 Booklet") {
    OutputDiagramContainer(settings: BookletSettings(
        outputPaper: .a4,
        layout: .bookletFold,
        marginMM: 5,
        gutterMM: 5,
        padBlankPage: true,
        addCutMarks: true
    ))
    .frame(width: 127, height: 176)
    .padding()
}

#Preview("Output Diagram - A5 Simple Pair") {
    OutputDiagramContainer(settings: BookletSettings(
        outputPaper: .a5,
        layout: .simplePair,
        marginMM: 10,
        gutterMM: 8,
        padBlankPage: true,
        addCutMarks: false
    ))
    .frame(width: 127, height: 176)
    .padding()
}
