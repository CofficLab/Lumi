import FactoryBookletMakerMobile
import FactoryCoreMobile
import SwiftUI

/// BookletMaker iOS 入口。
///
/// 由 `FactoryBookletMakerMobile` 在编译期组装最小插件目录，交给 iOS 宿主
/// 引擎 `FactoryCoreMobile` 启动内核并渲染插件面板（复用与 macOS 相同的
/// workspace 注册表）。
@main
struct BookletMakeriOSApp: App {
    @UIApplicationDelegateAdaptor(MobileAgent.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            FactoryBookletMakerMobile.makeMainScene()
        }
    }
}
