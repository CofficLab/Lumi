import LumiCoreKit
import SwiftUI

struct MenuBarIconView: View {
    let contentItems: [LumiMenuBarContentItem]
    let lumiCore: LumiCoreAccessing

    var body: some View {
        HStack(spacing: 4) {
            LogoView(scene: .statusBar, lumiCore: lumiCore)
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
