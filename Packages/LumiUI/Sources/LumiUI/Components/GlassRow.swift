import SwiftUI

public struct GlassRow<Content: View>: View {
    let content: Content
    @State private var isHovering = false

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DesignTokens.Spacing.md)
            .background(rowBackground)
            .overlay(rowBorder)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: DesignTokens.Duration.micro)) {
                    isHovering = hovering
                }
            }
    }

    private var rowBackground: some View {
        Group {
            if isHovering {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(DesignTokens.Material.glass.opacity(0.2))
            } else {
                SwiftUI.Color.clear
            }
        }
    }

    @ViewBuilder private var rowBorder: some View {
        if isHovering {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(SwiftUI.Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}
