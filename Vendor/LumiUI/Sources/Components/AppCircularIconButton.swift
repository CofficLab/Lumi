import SwiftUI

/// A compact circular control for dense playback and navigation toolbars.
///
/// It keeps the hit target, hover treatment, material surface, and semantic
/// theme colors consistent across apps while allowing the action to remain
/// owned by the feature that creates the button.
public struct AppCircularIconButton: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    let systemImage: String
    let accessibilityLabel: String?
    let tint: Color?
    let size: CGFloat
    let isActive: Bool
    let action: () -> Void

    public init(
        systemImage: String,
        accessibilityLabel: String? = nil,
        tint: Color? = nil,
        size: CGFloat = 32,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.tint = tint
        self.size = size
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(Circle().fill(DesignTokens.Material.glassUltra))
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(
                    color: DesignTokens.Shadow.subtle,
                    radius: 4,
                    y: 1
                )
                .contentShape(Circle())
                .scaleEffect(
                    isHovered && motionPreference.allowsMotion
                        ? AppUI.Motion.hoverScale
                        : 1
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemImage)
        .onHover { hovering in
            AppUI.Motion.animate(
                AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)
            ) {
                isHovered = hovering
            }
        }
    }

    private var iconColor: Color {
        if let tint { return tint }
        return isActive ? theme.textPrimary : theme.textSecondary
    }

    private var borderColor: Color {
        if isActive { return theme.primary.opacity(0.55) }
        if isHovered { return theme.textSecondary.opacity(0.28) }
        return theme.textSecondary.opacity(0.12)
    }
}

#Preview {
    HStack(spacing: 8) {
        AppCircularIconButton(systemImage: "ellipsis", accessibilityLabel: "More") {}
        AppCircularIconButton(systemImage: "backward.end.fill", accessibilityLabel: "Previous") {}
        AppCircularIconButton(systemImage: "play.fill", accessibilityLabel: "Play", isActive: true) {}
        AppCircularIconButton(systemImage: "forward.end.fill", accessibilityLabel: "Next") {}
        AppCircularIconButton(systemImage: "shuffle", accessibilityLabel: "Shuffle") {}
    }
    .padding()
    .background(Color.orange)
}
