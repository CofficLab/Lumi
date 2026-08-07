import LumiKernel
import LumiUI
import SwiftUI

struct VerbosityToolbarView: View {
    let kernel: LumiKernel

    // globalVerbosity 随当前会话切换可能变化（由 StateMonitorPlugin 双向同步）。
    // 用事件 + @State 缓存，不挂 kernel 全局总线。
    @State private var selectedLevel: LumiResponseVerbosity = .defaultVerbosity
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var isPopoverPresented = false

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var foregroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan
        case .standard:
            theme.textSecondary
        case .detailed:
            .purple
        }
    }

    private var backgroundColor: Color {
        switch selectedLevel {
        case .brief:
            Color.cyan.opacity(0.22)
        case .standard:
            theme.textSecondary.opacity(0.14)
        case .detailed:
            Color.purple.opacity(0.22)
        }
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedLevel.iconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(selectedLevel.levelCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedLevel.description)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VerbosityPopover(selectedLevel: selectedLevel) { level in
                // 写入全局详细程度，不再直接操作某个对话
                conversations?.setGlobalVerbosity(level)
                selectedLevel = level
                isPopoverPresented = false
            }
        }
        .task { refreshLevel() }
        .onLumiSelectedConversationDidChange { refreshLevel() }
    }

    private func refreshLevel() {
        selectedLevel = conversations?.globalVerbosity ?? .defaultVerbosity
    }
}
