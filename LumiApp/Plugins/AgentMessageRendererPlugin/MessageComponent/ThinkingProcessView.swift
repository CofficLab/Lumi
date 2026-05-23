import LumiUI
import SwiftUI

/// 思考过程展示视图（可展开/折叠）
/// 用于显示 AI 助手的思考过程，支持展开查看详情
struct ThinkingProcessView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 思考内容文本
    let thinkingText: String
    @LumiMotionPreferenceReader private var motionPreference
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
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Header 部分（可点击展开/折叠）
                MessageHeaderView {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.appMicroEmphasized)
                            .foregroundColor(theme.textSecondary)

                        Text(String(localized: "思考过程", table: "CoreMessageRenderer"))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)

                        // 折叠时展示一小段预览
                        if !isExpanded, !previewText.isEmpty {
                            Text(previewText)
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                } trailing: {
                    EmptyView()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    LumiMotion.animate(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference)) {
                        isExpanded.toggle()
                    }
                }

                Group {
                    // 思考内容（展开时显示）
                    if isExpanded && !thinkingText.isEmpty {
                        Divider()
                            .opacity(0.2)
                        Text(thinkingText)
                            .font(.appMonoCaption)
                            .foregroundColor(theme.textPrimary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .appDisclosureContentTransition(preference: motionPreference)
            }
        }
        .padding(.vertical, 4)
        .animation(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference), value: isExpanded)
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
