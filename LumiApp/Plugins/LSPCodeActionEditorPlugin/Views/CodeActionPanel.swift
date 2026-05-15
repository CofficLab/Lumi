import SwiftUI

/// 代码动作弹窗。
///
/// 用于展示当前光标、当前行或当前诊断可用的 Code Action 列表。
/// 数据来源可以是 LSP 返回的 `textDocument/codeAction` 结果，也可以是其它编辑器插件
/// 通过 `EditorCodeActionSuggestion` 提供的本地动作。
///
/// 该视图只负责展示和选择动作，不负责请求、解析或执行动作；真正的业务逻辑由
/// `CodeActionProvider` 和消费该 Provider 的编辑器 Overlay/面板负责。
struct CodeActionPanel: View {

    let actions: [CodeActionItem]
    @Binding var selectedIndex: Int
    let onActionSelected: (CodeActionItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "FF9F0A"))
                Text(String(localized: "Code Actions", table: "LSPCodeActionEditor"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if actions.indices.contains(selectedIndex),
                   actions[selectedIndex].isPreferred {
                    Text(String(localized: "Preferred", table: "LSPCodeActionEditor"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: "FF9F0A"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: "FF9F0A").opacity(0.14))
                        )
                }
                Text("\(actions.count) available")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "98989E").opacity(0.08))

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        CodeActionRow(
                            action: action,
                            isSelected: index == selectedIndex,
                            onTap: {
                                selectedIndex = index
                                onActionSelected(action)
                            }
                        )

                        if index < actions.count - 1 {
                            Divider().opacity(0.2)
                        }
                    }
                }
            }
        }
        .frame(width: 380, height: min(CGFloat(actions.count) * 36 + 60, 300))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.adaptive(light: "1C1C1E", dark: "FFFFFF").opacity(0.06),
                            Color(hex: "98989E").opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        )
    }
}

/// 代码动作列表中的单行动作视图。
///
/// 展示一个 `CodeActionItem` 的图标、标题和 preferred 标记。
/// 点击该行后会把选择事件回传给上层，由上层决定是否立即执行动作。
struct CodeActionRow: View {

    let action: CodeActionItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 16)

                Text(action.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if action.isPreferred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .yellow : Color(hex: "FF9F0A").opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 6).fill(Color(hex: "7C6FFF").opacity(0.9))
                    : RoundedRectangle(cornerRadius: 4).fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}
