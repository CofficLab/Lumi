import LumiCoreKit
import SwiftUI

struct CofficLogoView: View {
    var scene: LogoScene = .general

    @State private var isAnimating = false
    @State private var steamOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                switch scene {
                case .general, .appIcon, .about, .custom:
                    animatedLogo(size: size)
                case .statusBarInactive:
                    monochromeLogo(size: size)
                case .statusBarActive:
                    staticLogo(size: size)
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                guard allowsAnimation else { return }
                startAnimation()
            }
        }
    }

    private var allowsAnimation: Bool {
        switch scene {
        case .general, .appIcon, .about, .custom: true
        case .statusBarInactive, .statusBarActive: false
        }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            steamOffset = -8
        }
    }

    @ViewBuilder
    private func animatedLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.75

        // Background glow
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.brown.opacity(0.3),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: mainSize * 0.2,
                    endRadius: size * 0.5
                )
            )

        // Coffee cup body
        ZStack {
            // Cup body
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.28, blue: 0.15),
                            Color(red: 0.32, green: 0.18, blue: 0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: mainSize * 0.7, height: mainSize * 0.6)

            // Cup rim
            RoundedRectangle(cornerRadius: size * 0.04)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.38, blue: 0.22),
                            Color(red: 0.42, green: 0.26, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: mainSize * 0.75, height: mainSize * 0.12)
                .offset(y: -mainSize * 0.28)

            // Handle
            Circle()
                .stroke(
                    Color(red: 0.45, green: 0.28, blue: 0.15),
                    lineWidth: size * 0.04
                )
                .frame(width: mainSize * 0.25, height: mainSize * 0.25)
                .offset(x: mainSize * 0.38, y: -mainSize * 0.05)

            // Coffee surface
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.2, blue: 0.1),
                            Color(red: 0.25, green: 0.14, blue: 0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: mainSize * 0.6, height: mainSize * 0.15)
                .offset(y: -mainSize * 0.2)

            // Steam lines
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.03, height: size * 0.15)
                    .offset(
                        x: CGFloat(index - 1) * size * 0.08,
                        y: -mainSize * 0.35 + steamOffset
                    )
                    .opacity(isAnimating ? 0.3 : 0.7)
            }
        }
    }

    @ViewBuilder
    private func staticLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.75

        RoundedRectangle(cornerRadius: size * 0.08)
            .fill(Color.brown)
            .frame(width: mainSize * 0.7, height: mainSize * 0.6)

        RoundedRectangle(cornerRadius: size * 0.04)
            .fill(Color.brown.opacity(0.8))
            .frame(width: mainSize * 0.75, height: mainSize * 0.12)
            .offset(y: -mainSize * 0.28)

        Circle()
            .stroke(Color.brown, lineWidth: size * 0.04)
            .frame(width: mainSize * 0.25, height: mainSize * 0.25)
            .offset(x: mainSize * 0.38, y: -mainSize * 0.05)
    }

    @ViewBuilder
    private func monochromeLogo(size: CGFloat) -> some View {
        let mainSize = size * 0.75

        RoundedRectangle(cornerRadius: size * 0.08)
            .fill(.primary)
            .frame(width: mainSize * 0.7, height: mainSize * 0.6)

        RoundedRectangle(cornerRadius: size * 0.04)
            .fill(.primary.opacity(0.8))
            .frame(width: mainSize * 0.75, height: mainSize * 0.12)
            .offset(y: -mainSize * 0.28)

        Circle()
            .stroke(.primary, lineWidth: size * 0.04)
            .frame(width: mainSize * 0.25, height: mainSize * 0.25)
            .offset(x: mainSize * 0.38, y: -mainSize * 0.05)
    }
}

#Preview("Coffic Logo") {
    CofficLogoView(scene: .general)
        .frame(width: 64, height: 64)
}
