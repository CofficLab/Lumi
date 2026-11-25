import KernelCore
import LumiThemePack
import LumiUI
import PluginShowImage
import PluginRootView
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversation
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import ProviderToolbar
import SwiftUI

/// 装配期区域接线：把各区域 Provider 的贡献写入根视图。
///
/// `RootViewProviding` 的贡献字段是 `@Published`，写入必须发生在内核装配期。
/// 一旦放进视图构建路径，SwiftUI 会在 body 求值期间触发
/// "Publishing changes from within view updates"，因此视图侧只做纯读取。
///
/// 与 LumiFactory 共享接线的区别：Lumi 的根视图还有 Rail / 聊天分栏的可见性与
/// 宽度绑定，共享接线（工具栏 / 入口栏 / 内容区）覆盖不到，故宿主关闭共享接线、
/// 由本类型统一接线，`manifest.wireKernel` 调用一次。
@MainActor
public enum LumiRegionWiring {
    /// 写入根视图的区域贡献 + 桥接当前主题。必须在内核启动后、任何视图构建前调用。
    public static func wire(kernel: KernelCoreContainer) {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else { return }

        // ProviderTheme 与 LumiUI 是两层。先桥接选中主题，注入的视图才能与
        // SwiftUI 语义色 / AppKit 控件读到同一套外观。
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            DefaultViewFactory.syncLumiTheme(theme)
        }

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            rootView.setToolbarView(toolbar.makeToolbarView())
        }
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            rootView.setActivityBarView(activityBar.makeActivityBarView())
        }
        if let rail = kernel.resolveProvider((any RailViewProviding).self) {
            rootView.setRailView(rail.makeRailView())
            rootView.setRailViewVisible(rail.hasVisibleTabs)
            rootView.bindRailViewVisibility(to: rail)
            rootView.bindRailViewWidth(
                to: rail,
                onResize: rail.saveCurrentWidth
            )
        }
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            rootView.setContentView(contentView.makeContentView())
        }
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            // 分栏显隐跟随会话选中：会话由插件替换（PluginConversationManager
            // order=7）后必须在启动完成时才绑定，否则绑到的是被替换掉的内存实现。
            if let conversations = kernel.resolveProvider((any ConversationManaging).self) {
                chat.bindConversationSelection(conversations)
            }
            let trailingPane = RootTrailingPane(
                id: "com.coffic.lumi.workspace.chat",
                width: chat.chatSectionWidth,
                isVisible: chat.isVisible,
                content: chat.makeChatSectionView()
            )
            trailingPane.bindVisibility(to: chat)
            trailingPane.bindWidth(
                to: chat,
                onResize: chat.saveCurrentWidth
            )
            rootView.setTrailingPane(trailingPane)
        }
    }
}
