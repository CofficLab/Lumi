import SwiftUI

// MARK: - Booklet Explanation View

/// 示意图区域，展示 PDF 转换前后的效果
/// 会根据用户的设置实时更新，作为拖放区域下方的内容展示
struct BookletExplanationView: View {
    let settings: BookletSettings

    var body: some View {
        GeometryReader { geo in
            let size = computeDynamicSize(in: geo.size)

            VStack(spacing: 12 * size.scaleFactor) {
                // 示意图容器
                HStack(spacing: 32 * size.scaleFactor) {
                    // 左侧：输入（两页 A4 并排）
                    VStack(spacing: 6 * size.scaleFactor) {
                        InputDiagram(paperSize: settings.outputPaper)
                            .frame(width: size.inputWidth, height: size.inputHeight)
                            .animation(.easeInOut(duration: 0.3), value: settings.outputPaper)

                        Text(BookletLocalization.string("2 Original Pages"))
                            .font(.system(size: max(8, 10 * size.scaleFactor)))
                            .foregroundColor(.secondary)
                    }

                    // 中间：转换箭头
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20 * size.scaleFactor))
                        .foregroundColor(.accentColor)

                    // 右侧：输出（拼版后的页面）
                    VStack(spacing: 6 * size.scaleFactor) {
                        OutputDiagram(settings: settings)
                            .frame(width: size.outputWidth, height: size.outputHeight)
                            .animation(.easeInOut(duration: 0.3), value: settings)

                        Text(BookletLocalization.string("After conversion"))
                            .font(.system(size: max(8, 10 * size.scaleFactor)))
                            .foregroundColor(.secondary)
                    }
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
        let baseInputWidth: CGFloat = 260
        let baseInputHeight: CGFloat = 176
        let baseOutputWidth: CGFloat = 176
        let baseOutputHeight: CGFloat = 124

        // 内容区域预估宽度：输入 + 间距 + 箭头 + 间距 + 输出
        let baseContentWidth = baseInputWidth + 32 + 30 + 32 + baseOutputWidth
        let baseContentHeight = baseInputHeight + 40 // 加上标签和间距

        // 计算缩放因子，保持宽高比
        let availableContentWidth = availableSize.width - 32  // 留边距
        let availableContentHeight = availableSize.height - 60 // 留出说明文字和间距

        let widthScale = availableContentWidth / baseContentWidth
        let heightScale = availableContentHeight / baseContentHeight

        // 取较小值，确保内容不溢出
        let scale = min(widthScale, heightScale, 2.0) // 限制最大放大倍数为 2x

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
