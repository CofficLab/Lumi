import SwiftUI

// MARK: - A4 Paper View

/// A4 纸张示意图视图
/// 渲染一张 A4 比例的纸张，用于示意图展示
///
/// 支持两种使用方式：
/// 1. 默认模式：显示内置示例文字（水调歌头）
///    ```
///    A4PaperView(pageNumber: 1, height: 150)
///    ```
/// 2. 容器模式：传入自定义内容视图
///    ```
///    A4PaperView(height: 150) {
///        MyCustomView()
///    }
///    ```
struct A4PaperView: View {
    /// 页码（用于显示在左下角）
    let pageNumber: Int?

    /// 纸张高度（宽度会自动按 A4 比例计算）
    let height: CGFloat

    /// 自定义内容视图（nil 时使用内置示例文字）
    private let customContent: AnyView?

    /// 是否显示内置示例文字（容器模式下为 false）
    private let showDefaultContent: Bool

    /// 示例文字内容：不同页使用不同的内容，便于看出拼版前后的对应关系。
    static let pageOneSampleText = """
    项目概览
    Lumi Booklet Maker

    将多个 PDF 页面整理到适合打印的小册子版式中。
    支持设置纸张大小、页边距和装订线。

    这是一份示例文档的第一页，
    用于展示原始页面内容。
    """

    static let pageTwoSampleText = """
    使用步骤
    快速开始

    1. 拖入需要处理的 PDF 文件。
    2. 选择输出纸张与排列方式。
    3. 点击转换并预览生成结果。

    这是一份示例文档的第二页，
    用于确认页面内容被正确合并。
    """

    static func sampleText(for pageNumber: Int?) -> String {
        pageNumber == 2 ? pageTwoSampleText : pageOneSampleText
    }

    // A4 比例：210:297 ≈ 1:1.414
    private let aspectRatio: CGFloat = 210.0 / 297.0

    // MARK: - Initializers

    /// 默认初始化器，显示内置示例文字
    /// - Parameters:
    ///   - pageNumber: 页码
    ///   - showContent: 是否显示内容（false 时只显示纸张轮廓）
    ///   - height: 纸张高度
    init(pageNumber: Int? = nil, showContent: Bool = true, height: CGFloat = 127) {
        self.pageNumber = pageNumber
        self.height = height
        self.customContent = nil
        self.showDefaultContent = showContent
    }

    /// 容器初始化器，支持传入自定义内部视图
    /// - Parameters:
    ///   - pageNumber: 页码
    ///   - height: 纸张高度
    ///   - content: 自定义内容视图，会渲染在纸张内部
    init<V: View>(
        pageNumber: Int? = nil,
        height: CGFloat = 127,
        @ViewBuilder content: () -> V
    ) {
        self.pageNumber = pageNumber
        self.height = height
        self.customContent = AnyView(content())
        self.showDefaultContent = false
    }

    // MARK: - Body

    var body: some View {
        let width = height * aspectRatio

        ZStack {
            // 纸张背景
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // 纸张边框
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

            // 内容区域
            contentArea
                .padding(.horizontal, width * 0.08)
                .padding(.vertical, height * 0.08)

            // 页码标注
            if let pageNum = pageNumber {
                VStack {
                    Spacer()
                    HStack {
                        Text("Page \(pageNum)")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(3)
                }
            }
        }
        .frame(width: width, height: height)
    }

    /// 内容区域：自定义视图 或 内置示例文字
    @ViewBuilder
    private var contentArea: some View {
        if showDefaultContent {
            Text(Self.sampleText(for: pageNumber))
                .font(.system(size: 6))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
        } else if let content = customContent {
            content
        }
    }
}

// MARK: - Preview

#Preview("Default Text Content") {
    A4PaperView(pageNumber: 1, showContent: true, height: 150)
        .padding()
}

#Preview("Container Mode") {
    A4PaperView(pageNumber: 1, height: 150) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom Title")
                .font(.headline)
            Text("This is custom content inside the A4 paper view.")
                .font(.body)
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
        }
    }
    .padding()
}

#Preview("Container with Diagram") {
    A4PaperView(pageNumber: 2, height: 150) {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.largeTitle)
                .foregroundColor(.blue)
            Text("Booklet Preview")
                .font(.caption)
        }
    }
    .padding()
}

#Preview("Empty Container") {
    A4PaperView(pageNumber: nil, height: 150) {
        Color.clear
    }
    .padding()
}
