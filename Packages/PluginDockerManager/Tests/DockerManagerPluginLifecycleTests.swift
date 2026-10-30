import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import SwiftUI
import Testing
@testable import DockerManagerPlugin

// MARK: - Docker 插件生命周期

/// 观察内容区变更的记录盒（避免在逃逸闭包里直接改捕获变量）。
@MainActor
private final class ContentChangeBox {
    var changeCount = 0
}

@Suite("Docker 插件生命周期")
@MainActor
struct DockerManagerPluginLifecycleTests {

    @Test("注册时写入关于与说明书文档条目")
    func registerAddsDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = DockerManagerPlugin()
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.map(\.id) == [plugin.id])
        #expect(docs.manualEntries.map(\.id) == [plugin.id])
        #expect(docs.aboutEntries.first?.name == "Docker")
        #expect(docs.manualEntries.first?.name == "Docker")
    }

    @Test("缺少文档 Provider 时注册不抛错")
    func registerWithoutDocsProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try DockerManagerPlugin().onRegister(kernel: kernel)
    }

    @Test("启动后注册活动栏入口")
    func bootRegistersActivityBarItem() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)

        let plugin = DockerManagerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.items.count == 1)
        #expect(activityBar.items.first?.id == "\(plugin.id).entry")
        #expect(activityBar.items.first?.title == "Docker")
        #expect(activityBar.items.first?.systemImage == "shippingbox")
        #expect(activityBar.items.first?.ownerPluginID == plugin.id)
    }

    @Test("缺少活动栏 Provider 时启动不抛错")
    func bootWithoutActivityBarProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try DockerManagerPlugin().onBoot(kernel: kernel)
    }

    @Test("启动后入口被自动激活并切换内容区、工具栏与根视图")
    func bootActivatesEntryAndSwitchesChrome() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let content = DefaultContentViewProviding()
        let toolbar = DefaultToolbarProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let contentChanges = ContentChangeBox()
        content.addContentViewObserver { _ in contentChanges.changeCount += 1 }

        let plugin = DockerManagerPlugin()
        try plugin.onBoot(kernel: kernel)

        // ActivityBar 注册入口后会自动激活首个入口。
        #expect(activityBar.activeItemID == "\(plugin.id).entry")
        #expect(contentChanges.changeCount == 1)
        #expect(toolbar.toolbarItems.map(\.id) == ["\(plugin.id).title"])
        #expect(toolbar.toolbarItems.first?.placement == .center)
        #expect(toolbar.toolbarItems.first?.category == .system)
        #expect(toolbar.visibleCategories == [.global, .system])
        #expect(rootView.railView == nil)
        #expect(rootView.isContentHeaderViewHidden == true)
    }

    @Test("停用入口时恢复工具栏分类与根视图")
    func deactivationRestoresChrome() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let content = DefaultContentViewProviding()
        let toolbar = DefaultToolbarProviding()
        let railView = DefaultRailViewProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = DockerManagerPlugin()
        try plugin.onBoot(kernel: kernel)
        activityBar.activateItem(id: nil)

        #expect(activityBar.activeItemID == nil)
        #expect(toolbar.toolbarItems.isEmpty)
        #expect(toolbar.visibleCategories == Set(ToolbarItemCategory.allCases))
        #expect(rootView.isContentHeaderViewHidden == false)
        #expect(rootView.isRailViewVisible == railView.hasVisibleTabs)
        #expect(rootView.railView != nil)
    }

    @Test("重新激活入口时再次切换内容区")
    func reactivationSwitchesContentAgain() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let content = DefaultContentViewProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, content)

        let contentChanges = ContentChangeBox()
        content.addContentViewObserver { _ in contentChanges.changeCount += 1 }

        let plugin = DockerManagerPlugin()
        try plugin.onBoot(kernel: kernel)
        activityBar.activateItem(id: nil)
        activityBar.activateItem(id: "\(plugin.id).entry")

        #expect(activityBar.activeItemID == "\(plugin.id).entry")
        #expect(contentChanges.changeCount == 2)
    }

    @Test("关闭插件时移除活动栏入口与工具栏项")
    func shutdownRemovesActivityBarAndToolbarItems() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = DockerManagerPlugin()
        try plugin.onBoot(kernel: kernel)
        activityBar.activateItem(id: "\(plugin.id).entry")
        try plugin.onShutdown(kernel: kernel)

        #expect(activityBar.items.isEmpty)
        #expect(toolbar.toolbarItems.isEmpty)
    }

    @Test("注销时移除文档条目")
    func unregisterRemovesDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = DockerManagerPlugin()
        try plugin.onRegister(kernel: kernel)
        try plugin.onUnregister(kernel: kernel)

        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
    }
}
