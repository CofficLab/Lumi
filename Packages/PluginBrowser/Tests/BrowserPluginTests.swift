import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import SwiftUI
import Testing
@testable import BrowserPlugin

@Suite("PluginBrowser")
@MainActor
struct PluginBrowserTests {
    @Test("Browser 激活和关闭时管理 Rail 生命周期")
    func browserManagesRailLifecycle() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let contentView = DefaultContentViewProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        railView.addTabs([
            RailTabItem(id: "browser.files", category: .fileTree, title: "Files", systemImage: "folder") {
                Text("Files")
            },
        ])
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)

        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.activeItemID == "Browser.entry")
        #expect(chat.isVisible)
        #expect(!rootView.isRailViewVisible)

        activityBar.addItems([ActivityBarItem(
            id: "test.other.entry",
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: "test.other.entry")

        #expect(!chat.isVisible)
        #expect(rootView.isRailViewVisible)

        activityBar.activateItem(id: "Browser.entry")
        #expect(chat.isVisible)
        #expect(!rootView.isRailViewVisible)

        try plugin.onShutdown(kernel: kernel)

        #expect(chat.isVisible)
        #expect(rootView.isRailViewVisible)
    }

    @Test("Browser 激活期间持续压制 content header，退出时还原激活前的值")
    func browserSuppressesContentHeaderWhileActive() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        // 模拟 ProjectFiles：项目有打开文件 → header 应该可见。
        rootView.setContentHeaderViewHidden(false)
        #expect(!rootView.isContentHeaderViewHidden)

        // 必须保留插件实例：rootViewObserver 以 [weak self] 捕获插件，
        // 一次性实例会在 onBoot 返回后立刻释放，自保逻辑随之失效。
        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)

        // 激活时应隐藏 header。
        #expect(activityBar.activeItemID == "Browser.entry")
        #expect(rootView.isContentHeaderViewHidden)

        // 模拟 ProjectFiles 的 observer 在激活期间把 header 改回可见：
        // Browser 自身的 rootViewObserver 会同步纠正，因此这里应仍是隐藏态。
        rootView.setContentHeaderViewHidden(false)

        #expect(rootView.isContentHeaderViewHidden)

        // 退出时还原成激活前的值（header 可见），而不是无条件写 false。
        activityBar.addItems([ActivityBarItem(
            id: "test.other.entry",
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: "test.other.entry")

        #expect(!rootView.isContentHeaderViewHidden)
    }

    @Test("Browser 退出时不强行显示本该隐藏的 content header")
    func browserRestoresHiddenContentHeaderOnDeactivate() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        // 模拟 ProjectFiles：项目没有打开文件 → header 本该隐藏。
        rootView.setContentHeaderViewHidden(true)
        #expect(rootView.isContentHeaderViewHidden)

        let plugin = BrowserPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rootView.isContentHeaderViewHidden)

        activityBar.addItems([ActivityBarItem(
            id: "test.other.entry",
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: "test.other.entry")

        // 退出后不应露出空的 "No files open" 条。
        #expect(rootView.isContentHeaderViewHidden)
    }

    @Test("plugin metadata is stable")
    func pluginMetadata() {
        let plugin = BrowserPlugin()
        #expect(plugin.id == "Browser")
        #expect(plugin.metadata.name == "Browser")
        #expect(plugin.order == 102)
    }
}
