import SwiftUI

public struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @LumiTheme private var theme

    var cornerRadius: CGFloat
    var padding: EdgeInsets
    var showShadow: Bool
    var shadowIntensity: Double
    var glowColor: SwiftUI.Color?
    var borderIntensity: Double

    @ViewBuilder var content: Content

    public init(
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        showShadow: Bool = true,
        shadowIntensity: Double = 1.0,
        glowColor: SwiftUI.Color? = nil,
        borderIntensity: Double = 0.08,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showShadow = showShadow
        self.shadowIntensity = shadowIntensity
        self.glowColor = glowColor
        self.borderIntensity = borderIntensity
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(cardBackground)
            .overlay(cardBorder)
            .modifier(ShadowModifier(showShadow: showShadow, color: shadowColor, radius: shadowRadius, offset: shadowOffset))
            .glowEffect(
                color: glowColor ?? theme.glowAccent,
                radius: glowRadius,
                intensity: glowIntensity
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.Material.glass)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignTokens.Material.mysticGlass(for: colorScheme))
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        SwiftUI.Color.clear,
                        SwiftUI.Color.white.opacity(borderIntensity),
                        SwiftUI.Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var shadowColor: SwiftUI.Color {
        DesignTokens.Shadow.subtle.opacity(shadowIntensity)
    }

    private var shadowRadius: CGFloat {
        DesignTokens.Shadow.subtleRadius
    }

    private var shadowOffset: CGFloat {
        DesignTokens.Shadow.subtleOffset
    }

    private var glowRadius: CGFloat {
        glowColor != nil ? 12 : 0
    }

    private var glowIntensity: Double {
        glowColor != nil ? 0.3 : 0
    }
}

private struct ShadowModifier: ViewModifier {
    let showShadow: Bool
    let color: SwiftUI.Color
    let radius: CGFloat
    let offset: CGFloat

    func body(content: Content) -> some View {
        if showShadow {
            content
                .shadow(color: color, radius: radius, x: 0, y: offset)
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        GlassCard {
            Text("Default GlassCard")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        GlassCard(showShadow: false, glowColor: .purple) {
            Text("Glowing GlassCard")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .frame(width: 300)
    .background(Color.gray.opacity(0.15))
}
