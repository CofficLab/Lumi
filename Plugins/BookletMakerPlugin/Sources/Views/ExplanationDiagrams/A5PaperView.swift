import SwiftUI

// MARK: - A5 Paper View

/// A5 纸张示意图视图
/// 渲染一张 A5 比例的纸张，用于示意图展示
struct A5PaperView: View {
    /// 页码（用于显示在左下角）
    let pageNumber: Int?
    
    /// 是否显示模拟内容（文字线条）
    let showContent: Bool
    
    /// 纸张高度（宽度会自动按 A5 比例计算）
    let height: CGFloat
    
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
    
    // A5 比例：148:210 ≈ 1:1.419
    private let aspectRatio: CGFloat = 148.0 / 210.0
    
    init(pageNumber: Int? = nil, showContent: Bool = true, height: CGFloat = 127) {
        self.pageNumber = pageNumber
        self.showContent = showContent
        self.height = height
    }
    
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
            
            // 真实文字内容
            if showContent {
                Text(Self.sampleText)
                    .font(.system(size: 5))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .padding(.horizontal, width * 0.08)
                    .padding(.vertical, height * 0.08)
            }
            
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
}

// MARK: - Preview

#Preview("A5 Paper with content") {
    A5PaperView(pageNumber: 1, showContent: true, height: 150)
        .padding()
}

#Preview("A5 Paper without page number") {
    A5PaperView(pageNumber: nil, showContent: true, height: 150)
        .padding()
}

#Preview("A5 Paper without content") {
    A5PaperView(pageNumber: 2, showContent: false, height: 150)
        .padding()
}
