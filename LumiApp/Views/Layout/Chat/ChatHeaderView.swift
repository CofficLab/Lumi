import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatHeaderView: View {
    let items: [LumiChatSectionHeaderItem]

    var body: some View {
        AppToolbarContainer(
            height: 40,
            bottomShadowLevel: .md,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    item.makeView()
                }

                Spacer(minLength: 0)
            }
        }
    }
}
