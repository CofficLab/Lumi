import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

/// header 内容行的固定高度。
///
/// 悬停时操作按钮组（CopyMessageButton / AppIconButton(.compact) 等）会物化，
/// 它们高 26pt；非悬停时行内最高的元素是头像(24pt)。若不固定高度，
/// 按钮物化瞬间行高会从 24pt 跳到 26pt，造成 header 抖动。
/// 固定为 26pt 后行高恒定，所有子元素垂直居中。
private let compactHeaderContentHeight: CGFloat = 26

struct CompactMessageHeaderView<Leading: View, Trailing: View>: View {
    @LumiTheme private var theme

    let leading: Leading
    let trailing: Trailing

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            leading
            Spacer()
            trailing
        }
        .frame(height: compactHeaderContentHeight)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .appSurface(
            style: .custom(headerBackgroundColor),
            cornerRadius: 8,
            borderColor: theme.divider.opacity(isHovered ? 1.0 : 0.65)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }

    private var headerBackgroundColor: Color {
        isHovered
            ? theme.textSecondary.opacity(0.14)
            : theme.textSecondary.opacity(0.08)
    }
}
