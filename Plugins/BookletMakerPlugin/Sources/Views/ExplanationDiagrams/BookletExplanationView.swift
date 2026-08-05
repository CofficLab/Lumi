import SwiftUI

// MARK: - Booklet Explanation View

/// 示意图区域，展示 PDF 转换前后的效果
/// 会根据用户的设置实时更新，作为拖放区域下方的内容展示
struct BookletExplanationView: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            let size = computeDynamicSize(in: geo.size)

            VStack(spacing: 16 * size.scaleFactor) {
                // 上方：输入（两页 A4 并排）
                VStack(spacing: 4 * size.scaleFactor) {
                    InputDiagram(paperSize: settings.outputPaper)
                        .frame(width: size.inputWidth, height: size.inputHeight)
                        .animation(.easeInOut(duration: 0.3), value: settings.outputPaper)

                    Text(BookletLocalization.string("2 Original Pages"))
                        .font(.system(size: max(8, 10 * size.scaleFactor)))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 中间：转换箭头
                Image(systemName: "arrow.down")
                    .font(.system(size: 20 * size.scaleFactor))
                    .foregroundColor(.accentColor)

                // 下方：输出（拼版后的页面）
                VStack(spacing: 4 * size.scaleFactor) {
                    OutputDiagramContainer(settings: settings)
                        .frame(width: size.outputWidth, height: size.outputHeight)
                        .animation(.easeInOut(duration: 0.3), value: settings)

                    Text(BookletLocalization.string("After conversion"))
                        .font(.system(size: max(8, 10 * size.scaleFactor)))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                // 说明文字
                Text(descriptionText)
                    .font(.system(size: max(8, 10 * size.scaleFactor)))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.2), value: settings.layout)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Dynamic Layout

    /// 计算适配可用空间的比例尺寸
    private func computeDynamicSize(in availableSize: CGSize) -> DynamicSize {
        // 基准尺寸（设计稿尺寸）
        // InputDiagram: 两个 A4 竖版并排
        let baseInputHeight: CGFloat = 176
        let baseInputWidth: CGFloat = baseInputHeight * (210.0 / 297.0) * 2 + 8  // 两页 + 间距

        // OutputDiagramContainer: 一张横向 A4，内部并排放置两个缩小页面
        let baseOutputWidth: CGFloat = baseInputHeight   // 旋转后宽度 = 原高度
        let baseOutputHeight: CGFloat = baseInputHeight * (210.0 / 297.0)  // 旋转后高度 = 原宽度

        // 上下布局：宽度取两者最大，高度为两者之和 + 间距 + 箭头
        let baseContentWidth = max(baseInputWidth, baseOutputWidth)
        let baseContentHeight = baseInputHeight + 16 + 30 + 16 + baseOutputHeight

        // 计算缩放因子，保持宽高比
        let availableContentWidth = availableSize.width - 32    // 留边距
        let availableContentHeight = availableSize.height - 80  // 留出说明文字和间距

        let widthScale = availableContentWidth / baseContentWidth
        let heightScale = availableContentHeight / baseContentHeight

        // 取较小值，确保内容不溢出
        let scale = min(widthScale, heightScale, 2.0)

        return DynamicSize(
            inputWidth: baseInputWidth * scale,
            inputHeight: baseInputHeight * scale,
            outputWidth: baseOutputWidth * scale,
            outputHeight: baseOutputHeight * scale,
            scaleFactor: scale
        )
    }

    /// 根据布局模式生成说明文字
    private var descriptionText: String {
        switch settings.layout {
        case .bookletFold:
            return String(format: BookletLocalization.string("Print on %@ paper, fold in half, and staple to create a booklet."),
                         settings.outputPaper.displayName)
        case .simplePair:
            return String(format: BookletLocalization.string("Print two pages side by side on %@ paper."),
                         settings.outputPaper.displayName)
        }
    }

    // MARK: - Types

    private struct DynamicSize {
        let inputWidth: CGFloat
        let inputHeight: CGFloat
        let outputWidth: CGFloat
        let outputHeight: CGFloat
        let scaleFactor: CGFloat
    }
}

// MARK: - Preview

#Preview("Default Settings") {
    BookletExplanationView(settings: BookletSettings())
        .frame(width: 600, height: 400)
        .padding()
}

#Preview("Custom Settings") {
    BookletExplanationView(settings: BookletSettings(
        outputPaper: .a5,
        layout: .simplePair,
        marginMM: 15,
        gutterMM: 10,
        padBlankPage: true,
        addCutMarks: true
    ))
    .frame(width: 600, height: 400)
    .padding()
}
