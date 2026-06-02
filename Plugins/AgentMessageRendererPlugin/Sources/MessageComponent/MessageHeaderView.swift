import LumiUI
import SwiftUI

/// 消息头部通用容器，统一悬浮态、边距和背景样式。
public struct MessageHeaderView<Leading: View, Trailing: View>: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let leading: Leading
    public let trailing: Trailing

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    public init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            leading
            Spacer()
            trailing
        }
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
