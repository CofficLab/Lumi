import SwiftUI

/// Button interaction style for prominent media controls.
///
/// On macOS the control grows slightly on hover; on all platforms it scales
/// down while pressed. Both effects honor the user's reduced-motion setting.
public struct AppPlaybackControlButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        AppPlaybackControlButtonLabel(configuration: configuration)
    }
}

private struct AppPlaybackControlButtonLabel: View {
    let configuration: ButtonStyle.Configuration
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovering = false

    private var scale: CGFloat {
        guard motionPreference.allowsMotion else { return 1 }
        let hoverScale: CGFloat = isHovering ? 1.05 : 1
        let pressScale: CGFloat = configuration.isPressed ? LumiMotion.pressScale : 1
        return hoverScale * pressScale
    }

    var body: some View {
        configuration.label
            .scaleEffect(scale)
            .animation(LumiMotion.enabled(LumiMotion.press, preference: motionPreference), value: configuration.isPressed)
            .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovering)
            #if os(macOS) || os(visionOS)
            .onHover { isHovering = $0 }
            #endif
    }
}

public extension View {
    /// Wraps this label in a plain media-control button.
    func appPlaybackControlButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { self }
            .buttonStyle(AppPlaybackControlButtonStyle())
    }

    /// Adds an accessible media-control button with a spoken label.
    func appPlaybackControlButton(accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { self.accessibilityHidden(true) }
            .buttonStyle(AppPlaybackControlButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
            .help(accessibilityLabel)
    }
}
