import AppKit
import LumiUI
import SwiftUI

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            AppErrorBanner(message: LocalizedStringKey(message))

            AppButton(AppStoreConnectLocalization.string("Copy"), systemImage: "doc.on.doc", size: .small) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
        }
    }
}
