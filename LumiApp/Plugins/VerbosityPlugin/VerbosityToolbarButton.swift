import SwiftUI
import MagicAlert

/// 详细程度切换工具栏按钮
///
/// 显示当前详细程度图标和名称，点击在简洁 / 详细之间切换。
/// 切换对话时自动从数据库恢复该对话的详细程度偏好。
struct VerbosityToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 循环顺序
    private static let levelOrder: [ResponseVerbosity] = [.brief, .detailed]

    var body: some View {
        Button(action: {
            let currentIndex = Self.levelOrder.firstIndex(of: llmVM.verbosity) ?? 0
            let nextIndex = (currentIndex + 1) % Self.levelOrder.count
            let newLevel = Self.levelOrder[nextIndex]
            withAnimation {
                llmVM.setVerbosity(newLevel)
            }
            // 保存到当前对话的详细程度偏好
            conversationVM.saveVerbosityPreference(newLevel)
            alert_info(
                String(localized: "Switched to \(newLevel.displayName) Verbosity", table: "Verbosity"),
                subtitle: newLevel.description
            )
        }) {
            HStack(spacing: 4) {
                Image(systemName: llmVM.verbosity.iconName)
                    .font(.system(size: 13))
                Text(llmVM.verbosity.displayName)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(String(localized: "Verbosity", table: "Verbosity"))
        .accessibilityHint(String(localized: "Verbosity Hint", table: "Verbosity"))
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            if let preference = conversationVM.getVerbosityPreference() {
                llmVM.setVerbosity(preference)
            } else {
                llmVM.setVerbosity(.brief)
            }
        }
    }

    // MARK: - 计算属性

    private var foregroundColor: Color {
        switch llmVM.verbosity {
        case .brief:
            return Color.blue
        case .detailed:
            return Color.purple
        }
    }

    private var backgroundColor: Color {
        switch llmVM.verbosity {
        case .brief:
            return Color.blue.opacity(0.1)
        case .detailed:
            return Color.purple.opacity(0.1)
        }
    }

    private var helpText: String {
        switch llmVM.verbosity {
        case .brief:
            return String(localized: "Brief Verbosity Description", table: "Verbosity")
        case .detailed:
            return String(localized: "Detailed Verbosity Description", table: "Verbosity")
        }
    }
}
