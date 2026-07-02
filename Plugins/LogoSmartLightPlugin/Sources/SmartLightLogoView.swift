import LumiCoreKit
import SwiftUI

struct SmartLightLogoView: View {
    var scene: LogoScene = .general

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                switch scene {
                case .general, .appIcon, .about, .custom:
                    SmartLightAnimatedLogoView(size: size)
                case .statusBar:
                    // Menu bar icon rendered as monochrome template image (tinted by system), always monochrome, no active state.
                    SmartLightMonochromeLogoView(size: size)
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
