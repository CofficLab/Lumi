import SwiftUI

struct LogoView: View {
    var scene: LogoScene = .general

    var body: some View {
        SmartLightLogo(scene: scene)
    }
}
