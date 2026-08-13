import KernelLumi
import LumiUI
import SwiftUI

struct VerbosityToolbarView: View {
    let kernel: KernelLumi

    @State private var selectedLevel: LumiResponseVerbosity = .defaultVerbosity
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var isPopoverPresented = false

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    /// 当前是否有选中对话
    private var hasSelectedConversation: Bool {
        conversations?.selectedConversationID != nil
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
            VerbosityPopover(
                selectedLevel: selectedLevel,
                isConversationScope: hasSelectedConversation
            ) { level in
                updateVerbosity(level)
                isPopoverPresented = false
            }
        }
        .task { refreshLevel() }
        .onLumiSelectedConversationDidChange { refreshLevel() }
    }

    // MARK: - Actions

    /// 根据是否有选中对话，写入对话级别或全局详细程度
    private func updateVerbosity(_ level: LumiResponseVerbosity) {
        guard let conversations else { return }
        if let conversationID = conversations.selectedConversationID {
            // 有选中对话：同步到该对话的详细程度
            conversations.setVerbosity(level, for: conversationID)
            // 同时更新全局详细程度，使后续新建对话继承此设置
            conversations.setGlobalVerbosity(level)
        } else {
            // 无选中对话：直接修改全局详细程度
            conversations.setGlobalVerbosity(level)
        }
        selectedLevel = level
    }

    /// 刷新显示值：有对话时读取对话的详细程度，否则读取全局详细程度
    private func refreshLevel() {
        guard let conversations else {
            selectedLevel = .defaultVerbosity
            return
        }
        if let conversationID = conversations.selectedConversationID {
            selectedLevel = conversations.verbosity(for: conversationID)
        } else {
            selectedLevel = conversations.globalVerbosity
        }
    }
}
