import LumiCoreKit
import SwiftUI

struct CofficLogoView: View {
    var scene: LumiCore.LogoScene = .general
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                switch scene {
                case .general, .appIcon, .about, .custom:
                    CofficAnimatedLogoView(size: size)
                case .statusBar:
                    // 菜单栏图标渲染为单色模板图（由系统统一着色），恒为单色、无激活态。
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
