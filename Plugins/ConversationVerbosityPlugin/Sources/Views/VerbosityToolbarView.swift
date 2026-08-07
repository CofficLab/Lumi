import LumiKernel
import LumiUI
import SwiftUI

struct VerbosityToolbarView: View {
    let kernel: LumiKernel

    @StateObject private var box = ObservableConversationVerbosityBox()
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var isPopoverPresented = false

    /// 使用全局详细程度，不依赖具体对话
    private var selectedLevel: LumiResponseVerbosity {
        box.service?.globalVerbosity ?? .defaultVerbosity
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
                box.service?.setGlobalVerbosity(level)
                isPopoverPresented = false
            }
        }
        // 绑定到 conversations 这一个 service：本视图只订阅它的 objectWillChange，
        // 不再挂在 kernel 全局总线上，workspace/settings 等变更不会触发这里刷新。
        .task {
            box.bind(kernel.conversations)
        }
    }
}
