import LumiCoreKit
import SwiftUI

struct MenuBarIconView: View {
    let contentItems: [LumiMenuBarContentItem]

    var body: some View {
        HStack(spacing: 4) {
            // 菜单栏图标恒为单色模板图，颜色完全交给系统着色，无激活/非激活态。
            LogoView(scene: .statusBar)
                .frame(width: 20, height: 20)

            ForEach(contentItems) { item in
                item.makeView()
                    .fixedSize()
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 20)
    }
}
