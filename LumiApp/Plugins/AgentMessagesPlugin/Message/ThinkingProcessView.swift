import SwiftUI

/// 思考过程展示视图（可展开/折叠）
/// 用于显示 AI 助手的思考过程，支持展开查看详情
struct ThinkingProcessView: View {
    /// 思考内容文本
    let thinkingText: String
    /// 是否正在思考中
    let isThinking: Bool
    /// 是否已展开
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 展开/折叠按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(isThinking ? "思考过程..." : "思考过程")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(.orange)

                    if isThinking {
                        // 思考中的动画点
                        HStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 4, height: 4)
                                    .opacity(isThinking ? 1.0 : 0.5)
                                    .animation(
                                        .easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.2),
                                        value: isThinking
                                    )
                            }
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // 思考内容（展开时显示）
            if isExpanded && !thinkingText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(thinkingText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.gray)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("ThinkingProcessView - Small") {
    ThinkingProcessView(
        thinkingText: "这是一个示例思考过程文本，用于测试 ThinkingProcessView 组件的显示效果。",
        isThinking: true
    )
    .padding()
    .frame(width: 800, height: 600)
}

#Preview("ThinkingProcessView - Large") {
    ThinkingProcessView(
        thinkingText: "这是一个示例思考过程文本，用于测试 ThinkingProcessView 组件的显示效果。\n\n思考过程可以包含多行文本，展示 AI 助手的推理过程。",
        isThinking: false
    )
    .padding()
    .frame(width: 1200, height: 1200)
}
