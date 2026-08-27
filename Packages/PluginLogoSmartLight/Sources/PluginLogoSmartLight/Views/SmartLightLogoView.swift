import ProviderLogo
import SwiftUI

struct SmartLightLogoView: View {
    var scene: LogoScene = .general

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                switch scene {
                case .general, .about:
                    SmartLightAnimatedLogoView(size: size)
                case .statusBar, .statusBarHighlighted:
                    SmartLightMonochromeLogoView(
                        size: size,
                        isHighlighted: scene == .statusBarHighlighted
                    )
                }
            }
            .frame(width: size, height: size)
        }
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
            Text(LumiPluginLocalization.string("General", bundle: .module))
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .about)
                .frame(width: 48, height: 48)
            Text(LumiPluginLocalization.string("About", bundle: .module))
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .statusBar)
                .frame(width: 48, height: 48)
            Text(LumiPluginLocalization.string("Status Bar", bundle: .module))
                .font(.caption2)
        }
        VStack {
            SmartLightLogoView(scene: .statusBarHighlighted)
                .frame(width: 48, height: 48)
            Text(LumiPluginLocalization.string("Highlighted", bundle: .module))
                .font(.caption2)
        }
    }
    .padding()
}
