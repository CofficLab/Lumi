import SwiftUI

// MARK: - ShimmerModifier

/// A view modifier that overlays an animated shimmer (light sweep) effect.
///
/// Use on skeleton / placeholder views to indicate loading content.
/// The effect respects `LumiMotionPreference` and will fall back to a
/// static highlight when the user has reduced motion enabled.
struct ShimmerModifier: ViewModifier {
    let isActive: Bool

    @LumiMotionPreferenceReader private var motionPreference
    @State private var phase: CGFloat = -1.5

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.2),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        .offset(x: phase * width)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear { startAnimation() }
        } else {
            content
        }
    }

    private func startAnimation() {
        guard motionPreference.allowsMotion else { return }
        phase = -1.5
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            phase = 1.5
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Adds an animated shimmer (light sweep) overlay, typically used on
    /// skeleton / placeholder views during loading.
    ///
    /// When `isActive` is `false` the modifier is a no-op. The animation
    /// automatically respects the user's reduce-motion preference.
    ///
    /// - Parameter isActive: Whether the shimmer animation should run.
    /// - Returns: The modified view.
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
