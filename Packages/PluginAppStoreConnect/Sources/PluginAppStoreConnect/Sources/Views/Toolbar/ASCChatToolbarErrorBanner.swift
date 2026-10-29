import LumiUI
import SwiftUI

/// Chat Toolbar 弹层中的错误横幅。
struct ASCChatToolbarErrorBanner: View {
    let message: String

    var body: some View {
        AppErrorBanner(message: LocalizedStringKey(message))
            .padding(12)
    }
}
