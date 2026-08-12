import FactoryCore
import SwiftUI

/// FactoryBookletMaker 门面
///
/// 组装 BookletMaker 的最小插件目录，并把生命周期与 UI 工作委托给
/// `FactoryCore`。这是一个固定配置：不提供任意白名单 API，也不允许
/// 调用方扩充插件集合——BookletMaker 的插件组合在编译期就已确定。
@MainActor
public enum FactoryBookletMaker {
    /// BookletMaker 的固定配置。
    public static var configuration: FactoryConfiguration {
        // 16 个插件固定，ID 唯一性由 FactoryConfiguration 校验。
        // 失败意味着目录本身有缺陷，属于编译期/开发期错误。
        try! FactoryConfiguration(
            plugins: BookletMakerPluginCatalog.plugins,
            enabledPluginIDs: [BookletMakerPluginCatalog.bookletMakerPluginID],
            initialContainerID: BookletMakerPluginCatalog.bookletMakerPluginID,
            showsStatusBar: false,
            showsActivityBar: false
        )
    }

    /// 创建主窗口视图。
    public static func makeMainWindow() -> some View {
        FactoryCore.makeMainWindow(configuration: configuration) {
            BookletMakerLoadingView()
        }
    }

    /// 创建设置窗口视图。
    public static func makeSettingsWindow() -> some View {
        FactoryCore.makeSettingsWindow()
    }

    /// 创建应用命令菜单。
    public static func makeCommands() -> some Commands {
        FactoryCore.makeCommands()
    }
}
