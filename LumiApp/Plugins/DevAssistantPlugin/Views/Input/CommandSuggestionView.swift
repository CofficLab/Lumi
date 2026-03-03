
import SwiftUI

/// 命令建议视图
/// 显示与当前输入匹配的命令建议列表，支持键盘上下键选择
struct CommandSuggestionView: View {
    /// 视图模型：管理命令建议的显示和选择状态
    @ObservedObject var viewModel: CommandSuggestionViewModel
    /// 命令选择回调：当用户选择建议命令时触发
    var onSelect: (CommandSuggestion) -> Void

    var body: some View {
        if viewModel.isVisible {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button(action: {
                        onSelect(suggestion)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text(suggestion.command)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(suggestion.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index == viewModel.selectedIndex ? Color.accentColor.opacity(0.1) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .frame(maxWidth: 400)
            .padding(.bottom, 8)
        }
    }
}
