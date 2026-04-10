import MagicKit
import SwiftUI

/// 思考过程展示视图（可展开/折叠）
/// 用于显示 AI 助手的思考过程，支持展开查看详情
struct ThinkingProcessView: View {
    /// 思考内容文本
    let thinkingText: String
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
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)

                    Text("思考过程")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)

                    // 折叠时展示一小段预览，降低存在感但能提示有内容
                    if !isExpanded, !previewText.isEmpty {
                        Text(previewText)
                            .font(AppUI.Typography.caption2)
                            .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            } trailing: {
                EmptyView()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            // 思考内容（展开时显示）：深色块 + 固定浅色字，保证任意主题下都清晰可读
            if isExpanded && !thinkingText.isEmpty {
                AppCard(
                    style: .subtle,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                ) {
                    Text(thinkingText)
                        .font(AppUI.Typography.code)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("ThinkingProcessView - Small") {
    ThinkingProcessView(
        thinkingText: "这是一个示例思考过程文本，用于测试 ThinkingProcessView 组件的显示效果。"
    )
    .padding()
    .frame(width: 800, height: 600)
}

#Preview("ThinkingProcessView - Large") {
    ThinkingProcessView(
        thinkingText: "这是一个示例思考过程文本，用于测试 ThinkingProcessView 组件的显示效果。\n\n思考过程可以包含多行文本，展示 AI 助手的推理过程。"
    )
    .padding()
    .frame(width: 1200, height: 1200)
}
