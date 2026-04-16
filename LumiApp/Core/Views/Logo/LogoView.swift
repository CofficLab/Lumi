import AppKit
import MagicKit
import OSLog
import SwiftUI

struct LogoView: View {
    var scene: LogoScene = .general

    var body: some View {
        SmartLightLogo(scene: scene)
    }
}

// MARK: - Previews

#Preview("SmartLightLogo - All Scenes") {
    VStack(spacing: 30) {
        SmartLightLogo(scene: .general)
            .frame(width: 200, height: 200)
            .padding()
            .background(Color.black.opacity(0.8))

        HStack(spacing: 20) {
            SmartLightLogo(scene: .statusBarInactive)
                .frame(width: 40, height: 40)
                .background(Color.black)

            SmartLightLogo(scene: .statusBarInactive)
                .frame(width: 40, height: 40)
                .background(Color.white)
        }
        .padding()
    }
}

#Preview("LogoView - All Scenes") {
    ScrollView {
        VStack(spacing: 40) {
            HStack(spacing: 30) {
                VStack {
                    LogoView(scene: .general)
                        .frame(width: 120, height: 120)
                    Text("General").font(.caption)
                }

                VStack {
                    LogoView(scene: .appIcon)
                        .frame(width: 120, height: 120)
                    Text("App Icon").font(.caption)
                }

                VStack {
                    LogoView(scene: .about)
                        .frame(width: 120, height: 120)
                    Text("About").font(.caption)
                }
            }

            HStack(spacing: 30) {
                VStack {
                    LogoView(scene: .statusBarInactive)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                    Text("Status Bar (Inactive)").font(.caption)
                }

                VStack {
                    LogoView(scene: .statusBarActive)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                    Text("Status Bar (Active)").font(.caption)
                }
            }
        }
        .padding()
    }
    .frame(height: 600)
}

#Preview("LogoView - Snapshot") {
    LogoView(scene: .appIcon)
        .inMagicContainer(.init(width: 1024, height: 1024), scale: 0.5)
}
