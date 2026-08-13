import KernelLumi
import SwiftUI

struct CofficLogoView: View {
    var scene: LogoScene = .general
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                switch scene {
                case .general, .appIcon, .about, .custom:
                    CofficAnimatedLogoView(size: size)
                case .statusBar, .statusBarHighlighted:
                    CofficMonochromeLogoView(size: size)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

#Preview("Coffic Logo") {
    CofficLogoView(scene: .general)
        .frame(width: 64, height: 64)
}
