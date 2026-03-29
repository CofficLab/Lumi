import SwiftUI

/// 消息头部通用容器，统一悬浮态、边距和背景样式。
struct MessageHeaderView<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(headerBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(Color.white.opacity(isHovered ? 0.18 : 0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
            .fill(
                isHovered
                    ? DesignTokens.Color.semantic.textSecondary.opacity(0.14)
                    : DesignTokens.Color.semantic.textSecondary.opacity(0.08)
            )
    }
}
