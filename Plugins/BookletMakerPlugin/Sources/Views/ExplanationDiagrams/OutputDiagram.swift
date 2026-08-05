import SwiftUI

// MARK: - Output Diagram

/// 输出示意图：显示转换后的页面
/// 整个视图被 A4PaperView 包裹（旋转 90 度），尺寸与 InputDiagram 中的单个 A4 纸张一致
/// 根据设置动态显示边距、间距、裁切标记等
struct OutputDiagram: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            // 计算可用的内部尺寸（减去 A4PaperView 的内边距）
            let contentWidth = geo.size.width * (1 - 2 * 0.08)
            let contentHeight = geo.size.height * (1 - 2 * 0.08)

            // 根据设置计算边距和间距的显示比例
            let marginRatio = settings.marginMM / 30.0  // 最大 30mm 作为参考
            let gutterRatio = settings.gutterMM / 30.0

            let marginDisplay = max(2, min(20, contentWidth * marginRatio * 0.15))
            let gutterDisplay = max(1, min(15, contentWidth * gutterRatio * 0.1))

            let pageAreaWidth = contentWidth - 2 * marginDisplay - gutterDisplay
            let pageWidth = pageAreaWidth / 2
            let pageHeight = contentHeight - 2 * marginDisplay

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

                // 两个页面（使用 A4 视图旋转 90 度）
                HStack(spacing: gutterDisplay) {
                    outputPageView(pageNumber: nil, height: pageHeight)
                        .frame(width: pageWidth)

                    outputPageView(pageNumber: nil, height: pageHeight)
                        .frame(width: pageWidth)
                }
                .padding(.horizontal, marginDisplay)
                .padding(.vertical, marginDisplay)

                // 装订线（gutter）区域显示
                if gutterDisplay > 2 && settings.layout == .bookletFold {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: gutterDisplay, height: contentHeight - 2 * marginDisplay)
                        .position(x: contentWidth / 2, y: contentHeight / 2)

                    // 折叠虚线
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 1, height: contentHeight - 2 * marginDisplay)
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
                        .frame(width: 1, height: contentHeight - 2 * marginDisplay)
                        .position(x: contentWidth / 2, y: contentHeight / 2)
                }

                // 裁切标记
                if settings.addCutMarks {
                    CutMarksView(margin: marginDisplay, gutter: gutterDisplay, showGutter: settings.layout == .bookletFold)
                }
            }
            .frame(width: contentWidth, height: contentHeight)
        }
    }

    /// 根据输出纸张大小返回对应的纸张视图
    @ViewBuilder
    private func outputPageView(pageNumber: Int?, height: CGFloat) -> some View {
        // 输出示意图中的小页面：使用 A4 视图并旋转 90 度，与输入保持一致的视觉风格
        A4PaperView(pageNumber: pageNumber, showContent: true, height: height)
            .rotationEffect(.degrees(-90))
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

/// 输出示意图容器：用 A4PaperView 包裹 OutputDiagram（旋转 90 度）
/// 确保输出示意图的尺寸与 InputDiagram 中的单个 A4 纸张一致
struct OutputDiagramContainer: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            let pageHeight = geo.size.height
            let pageWidth = pageHeight * (210.0 / 297.0)  // A4 比例

            A4PaperView(pageNumber: nil, height: pageHeight) {
                OutputDiagram(settings: settings)
            }
            .rotationEffect(.degrees(-90))
            .frame(width: pageWidth, height: pageHeight)
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
