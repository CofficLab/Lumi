import LumiUI
import SwiftUI

/// 在全局工具栏中打开 App Store Connect。
@MainActor
struct AppStoreConnectOpenToolbarButton: View {
    @Environment(\.openURL) private var openURL

    private let appStoreConnectURL = URL(string: "https://appstoreconnect.apple.com")!

    var body: some View {
        AppIconButton(systemImage: "safari") {
            openURL(appStoreConnectURL)
        }
        .help(AppStoreConnectLocalization.string("Open App Store Connect"))
    }
}
