import SwiftUI

// MARK: - Story Page View

/// 故事页视图：按 A 系列纸张竖版比例渲染一页示例故事内容。
/// 用于示意图区域的输入页面条、拼版页预览和翻页书本。
struct StoryPageView: View {
    /// 页码（1-based，对应 SampleStory）
    let pageNumber: Int

    /// 纸张高度（宽度自动按比例计算）
    let height: CGFloat

    /// 内容缩放：控制文字相对纸张的大小（小缩略图时适当放大字号）
    var textScale: CGFloat = 1.0

    // A 系列竖版比例：宽 : 高 = 1 : √2
    private let aspectRatio: CGFloat = 1.0 / 1.414

    var body: some View {
        let width = height * aspectRatio

        ZStack {
            // 纸张背景
            FixedWhitePaperSurface()
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // 纸张边框
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.black.opacity(0.22), lineWidth: 1)

            // 故事内容
            if let page = SampleStory.page(pageNumber) {
                VStack(spacing: height * 0.04) {
                    Text(page.icon)
                        .font(.system(size: height * 0.14))

                    Text(page.title)
                        .font(.system(size: max(5, height * 0.055 * textScale), weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    Text(page.body)
                        .font(.system(size: max(4, height * 0.042 * textScale)))
                        .foregroundColor(.black.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                }
                .padding(.horizontal, width * 0.08)
                .padding(.vertical, height * 0.06)
            }

            // 页码标注（左下角）
            VStack {
                Spacer()
                HStack {
                    Text("\(pageNumber)")
                        .font(.system(size: max(5, height * 0.05), weight: .medium))
                        .foregroundColor(.black.opacity(0.65))
                    Spacer()
                }
                .padding(3)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Preview

#Preview("Story Pages") {
    HStack(spacing: 12) {
        ForEach(SampleStory.pages) { page in
            StoryPageView(pageNumber: page.id, height: 140)
        }
    }
    .padding()
}
