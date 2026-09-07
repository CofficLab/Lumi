#if !os(macOS)
import FactoryBookletMakerIOS
import SwiftUI

/// iOS 应用入口：只做组装，场景根视图由 Factory 提供。
/// 每个 scene 的移动会话（feature）由根视图持有。
struct BookletMakerIOSApp: App {
    var body: some Scene {
        WindowGroup {
            FactoryBookletMakerIOS.makeMobileRootView()
        }
    }
}
#endif
