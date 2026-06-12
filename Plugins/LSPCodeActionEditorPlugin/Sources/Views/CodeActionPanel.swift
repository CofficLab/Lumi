import LumiUI
import SwiftUI
import EditorService
import LumiCoreKit

/// 代码动作弹窗。
///
/// 用于展示当前光标、当前行或当前诊断可用的 Code Action 列表。
/// 数据来源可以是 LSP 返回的 `textDocument/codeAction` 结果，也可以是其它编辑器插件
/// 通过 `EditorCodeActionSuggestion` 提供的本地动作。
///
/// 该视图只负责展示和选择动作，不负责请求、解析或执行动作；真正的业务逻辑由
/// `CodeActionProvider` 和消费该 Provider 的编辑器 Overlay/面板负责。
public struct CodeActionPanel: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let actions: [CodeActionItem]
    @Binding var selectedIndex: Int
    public let onActionSelected: (CodeActionItem) -> Void

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(theme.warning)
                Text(LumiPluginLocalization.string("Code Actions", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                if actions.indices.contains(selectedIndex),
                   actions[selectedIndex].isPreferred {
                    Text(LumiPluginLocalization.string("Preferred", bundle: .module))
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.warning.opacity(0.14)))
                }
                Text("\(actions.count) available")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.appToolbarBackground)

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
        .appSurface(style: .popover, cornerRadius: 10, borderColor: theme.appSubtleBorder, lineWidth: 0.75)
        .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

/// 代码动作列表中的单行动作视图。
///
/// 展示一个 `CodeActionItem` 的图标、标题和 preferred 标记。
/// 点击该行后会把选择事件回传给上层，由上层决定是否立即执行动作。
public struct CodeActionRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let action: CodeActionItem
    public let isSelected: Bool
    public let onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.appCaption)
                    .foregroundColor(isSelected ? .white : theme.textSecondary)
                    .frame(width: 16)

                Text(action.title)
                    .font(.appCaption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if action.isPreferred {
                    Image(systemName: "star.fill")
                        .font(.appMicro)
                        .foregroundColor(isSelected ? .yellow : theme.warning.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appSurface(style: .custom(isSelected ? theme.primary.opacity(0.9) : Color.clear), cornerRadius: isSelected ? 6 : 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}
