import SwiftUI

/// Animated smart light logo view
/// Used for general, appIcon, about, custom scenes
struct SmartLightAnimatedLogoView: View {
    let size: CGFloat

    @State private var isBreathing = false

    var body: some View {
        let mainSize = size * 0.8

        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: mainSize * 0.3,
                        endRadius: size * 0.5
                    )
                )
                .scaleEffect(isBreathing ? 1.15 : 1)
                .opacity(isBreathing ? 1 : 0.6)

            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .orange,
                            .yellow.opacity(0.85)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: mainSize, height: mainSize)
                .shadow(color: .orange.opacity(0.3), radius: isBreathing ? 8 : 4)

            // Lightning bolt icon
            Image(systemName: "bolt.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white)
                .frame(width: mainSize * 0.35, height: mainSize * 0.35)
                .shadow(color: .white.opacity(0.6), radius: 2)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

#Preview("Animated Logo") {
    SmartLightAnimatedLogoView(size: 64)
}