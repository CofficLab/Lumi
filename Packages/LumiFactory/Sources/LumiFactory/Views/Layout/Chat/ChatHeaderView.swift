import LumiKernel
import LumiUI
import SwiftUI

struct ChatHeaderView: View {
    @ObservedObject var kernel: LumiKernel

    private var items: [ChatSectionHeaderItem] {
        kernel.chatSection?.allChatSectionHeaderItems ?? []
    }

    var body: some View {
        AppToolbarContainer(
            height: 40,
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
        .borderBottom()
    }
}