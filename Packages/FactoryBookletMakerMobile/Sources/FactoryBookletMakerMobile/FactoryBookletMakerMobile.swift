import FactoryCoreMobile
import LumiKernel
import SwiftUI

/// iOS 版 BookletMaker 组合门面。
///
/// 对应 macOS 的 `FactoryBookletMaker`：在编译期确定 16 个插件的最小目录，
/// 交给 iOS 宿主引擎 `FactoryCoreMobile` 启动内核并渲染。
@MainActor
public enum FactoryBookletMakerMobile {
    /// BookletMaker 插件 ID，启动后激活该容器。
    public static let bookletMakerPluginID = BookletMakerPluginCatalog.bookletMakerPluginID

    /// 组装并呈现 BookletMaker 主界面。
    public static func makeMainScene() -> some View {
        FactoryCoreMobile.makeMainScene(
            plugins: BookletMakerPluginCatalog.plugins,
            enabledPluginIDs: [bookletMakerPluginID],
            initialContainerID: bookletMakerPluginID
        )
    }
}
