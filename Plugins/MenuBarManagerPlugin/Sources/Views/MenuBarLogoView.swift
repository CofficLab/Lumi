import AppKit
import LumiKernel
import SwiftUI

/// 状态栏最左侧的 Logo 视图:优先展示最高优先级插件 Logo,回退到应用图标。
struct MenuBarLogoView: View {
    let kernel: LumiKernel

    private var logoItem: LogoItem? {
        kernel.logo?.highestPriorityLogoItem
    }

    private var logoView: AnyView? {
        logoItem?.makeView(.statusBar)
    }

    var body: some View {
        Group {
            if let view = logoView {
                view
            } else {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .renderingMode(.template)
            }
        }
        .frame(width: 16, height: 16)
    }
}
