import SwiftUI

/// 应用入口：按平台选择对应的实现。
/// - macOS: BookletMakerMacApp
/// - iOS / iPadOS: BookletMakerIOSApp
@main
struct BookletMakerApp: App {
    var body: some Scene {
        #if os(macOS)
        BookletMakerMacApp().body
        #else
        BookletMakerIOSApp().body
        #endif
    }
}
