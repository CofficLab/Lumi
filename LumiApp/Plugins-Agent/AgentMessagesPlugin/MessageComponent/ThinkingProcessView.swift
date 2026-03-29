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

    /// 折叠状态下展示的预览文本（首行 + 截断）
    private var previewText: String {
        let trimmed = thinkingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        if firstLine.count > 40 {
            let prefix = firstLine.prefix(40)
            return String(prefix) + "…"
        }
        return firstLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MessageHeaderView {
                withAnimation(.easeInOut(duration: 0.2)) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        Text(isThinking ? "思考过程…" : "思考过程")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                        // 折叠时展示一小段预览，降低存在感但能提示有内容
                        if !isExpanded, !previewText.isEmpty {
                            Text(previewText)
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            } trailing: {
                // 思考中的动画点
                if isThinking {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(DesignTokens.Color.semantic.textSecondary)
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // 思考内容（展开时显示）：深色块 + 固定浅色字，保证任意主题下都清晰可读
            if isExpanded && !thinkingText.isEmpty {
                AppCard(
                    style: .subtle,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ) {
                    ScrollView(showsIndicators: true) {
                        Text(thinkingText)
                            .font(DesignTokens.Typography.code)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 220)
                }
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
