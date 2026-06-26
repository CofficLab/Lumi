import LumiCoreKit
import SwiftUI

struct SmartLightLogoView: View {
    var scene: LogoScene = .general

    @State private var isBreathing = false

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                switch scene {
                case .general, .appIcon, .about, .custom:
                    animatedColorLogo(size: size)
                case .statusBar:
                    // 菜单栏图标渲染为单色模板图（由系统统一着色），恒为单色、无激活态。
                    monochromeLogo(size: size)
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                guard allowsAnimation else {
                    return
                }

                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    private var allowsAnimation: Bool {
        switch scene {
        case .general, .appIcon, .about, .custom:
            true
        case .statusBar:
            false
        }
    }

    @ViewBuilder
    private func animatedColorLogo(size: CGFloat) -> some View {
        colorLogo(size: size, glowScale: isBreathing ? 1.15 : 1, glowOpacity: isBreathing ? 1 : 0.6)
    }

    @ViewBuilder
    private func colorLogo(size: CGFloat, glowScale: CGFloat, glowOpacity: Double) -> some View {
        let mainSize = size * 0.8

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
            .scaleEffect(glowScale)
            .opacity(glowOpacity)

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
            .shadow(color: .orange.opacity(0.3), radius: glowScale > 1 ? 8 : 4)

        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.white)
            .frame(width: mainSize * 0.35, height: mainSize * 0.35)
            .shadow(color: .white.opacity(0.6), radius: 2)
    }

    @ViewBuilder
    private func monochromeLogo(size: CGFloat) -> some View {
        Circle()
            .fill(.primary)
            .frame(width: size * 0.8, height: size * 0.8)

        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.primary)
            .colorInvert()
            .frame(width: size * 0.5, height: size * 0.5)
    }
}

#Preview("General") {
    SmartLightLogoView(scene: .general)
        .frame(width: 64, height: 64)
}

#Preview("All Scenes") {
    HStack(spacing: 20) {
        VStack {
            SmartLightLogoView(scene: .general)
                .frame(width: 48, height: 48)
            Text("General")
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .appIcon)
                .frame(width: 48, height: 48)
            Text("App Icon")
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .about)
                .frame(width: 48, height: 48)
            Text("About")
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .statusBar)
                .frame(width: 48, height: 48)
            Text("Status Bar")
                .font(.caption2)
        }
    }
    .padding()
}
