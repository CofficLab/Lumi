import SwiftUI

// MARK: - Output Diagram

/// 输出示意图：显示转换后的页面
/// 根据设置动态显示边距、间距、裁切标记等
struct OutputDiagram: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            // 根据设置计算边距和间距的显示比例
            let marginRatio = settings.marginMM / 30.0  // 最大 30mm 作为参考
            let gutterRatio = settings.gutterMM / 30.0

            let marginDisplay = max(2, min(20, width * marginRatio * 0.15))
            let gutterDisplay = max(1, min(15, width * gutterRatio * 0.1))

            let pageAreaWidth = width - 2 * marginDisplay - gutterDisplay
            let pageWidth = pageAreaWidth / 2
            let pageHeight = height - 2 * marginDisplay

            ZStack {
                // 输出纸张外框
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                // 边距区域（用淡色表示）
                if marginDisplay > 2 {
                    // 左边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: marginDisplay)
                        .position(x: marginDisplay / 2, y: height / 2)

                    // 右边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(width: marginDisplay)
                        .position(x: width - marginDisplay / 2, y: height / 2)

                    // 上边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(height: marginDisplay)
                        .position(x: width / 2, y: marginDisplay / 2)

                    // 下边距
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.05))
                        .frame(height: marginDisplay)
                        .position(x: width / 2, y: height - marginDisplay / 2)
                }

                // 两个页面（根据输出纸张大小选择 A4 或 A5）
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
                        .frame(width: gutterDisplay, height: height - 2 * marginDisplay)
                        .position(x: width / 2, y: height / 2)

                    // 折叠虚线
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 1, height: height - 2 * marginDisplay)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundColor(.accentColor.opacity(0.6))
                        )
                        .position(x: width / 2, y: height / 2)
                } else if settings.layout == .simplePair {
                    // Simple Pair 模式下显示分割线
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 1, height: height - 2 * marginDisplay)
                        .position(x: width / 2, y: height / 2)
                }

                // 裁切标记
                if settings.addCutMarks {
                    CutMarksView(margin: marginDisplay, gutter: gutterDisplay, showGutter: settings.layout == .bookletFold)
                }

                // 尺寸标注
                VStack {
                    Spacer()
                    HStack {
                        Text(outputLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(4)
                }
            }
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

// MARK: - Preview

#Preview("Output Diagram - A4 Booklet") {
    OutputDiagram(settings: BookletSettings(
        outputPaper: .a4,
        layout: .bookletFold,
        marginMM: 5,
        gutterMM: 5,
        padBlankPage: true,
        addCutMarks: true
    ))
    .frame(width: 180, height: 127)
    .padding()
}

#Preview("Output Diagram - A5 Simple Pair") {
    OutputDiagram(settings: BookletSettings(
        outputPaper: .a5,
        layout: .simplePair,
        marginMM: 10,
        gutterMM: 8,
        padBlankPage: true,
        addCutMarks: false
    ))
    .frame(width: 180, height: 127)
    .padding()
}
