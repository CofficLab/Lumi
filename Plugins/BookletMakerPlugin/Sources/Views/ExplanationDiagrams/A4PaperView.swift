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

    /// 示例文字内容（苏轼《水调歌头》）
    static let sampleText = """
    水调歌头
    苏轼

    明月几时有？把酒问青天。
    不知天上宫阙，今夕是何年。
    我欲乘风归去，又恐琼楼玉宇，
    高处不胜寒。起舞弄清影，
    何似在人间。

    转朱阁，低绮户，照无眠。
    不应有恨，何事长向别时圆？
    人有悲欢离合，月有阴晴圆缺，
    此事古难全。但愿人长久，
    千里共婵娟。
    """

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
            Text(Self.sampleText)
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
