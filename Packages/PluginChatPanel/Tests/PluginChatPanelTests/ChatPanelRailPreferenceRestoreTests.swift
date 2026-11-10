import Foundation
import KernelCore
import PluginChatPanel
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
import ProviderRailView
import ProviderStorage
import SwiftUI
import Testing
@testable import PluginChatPanel

/// 重新进入 Chat 时必须恢复离开前选择的 Rail 标签。
///
/// #887：Chat 重新激活的回调里，代码先启用 Rail 观察者并收窄可见分类，
/// 之后才读取上次保存的标签。分类变化会在 `setVisibleCategories` 内**同步**
/// 触发 `reconcileActiveTab()`，把原本选中的标签换成 `visibleTabs[0]`
/// （回退项），并立即发出 `activeTabChanged`。
///
/// 观察者同步响应这个事件，把**临时回退项**写进了偏好存储。等到恢复流程
/// 去读偏好时，读到的已经是刚被覆盖的错误值 —— 用户的选择永久丢失。
///
/// 整个覆盖发生在同一次 MainActor 激活调用中，不依赖异步时序。
///
/// ## 为什么既有测试没抓到
///
/// `chatRestoresLastActiveRailTab` 只注册了两个 `.chat` 分类的 tab。切换
/// 可见分类时原标签仍然可见，`reconcileActiveTab` 不会改动它，因此没有
/// 触发回退。真实场景是 **Explorer（`.fileTree`）+ Chats（`.chat`）** 混在
/// 一起，回退项必然产生。
@Suite("ChatPanel Rail 偏好恢复")
@MainActor
struct ChatPanelRailPreferenceRestoreTests {

    /// 建一个带临时存储的 Kernel 与 Rail。
    private func makeEnvironment(
        storageRoot: URL
    ) throws -> (
        kernel: KernelCoreContainer,
        activityBar: DefaultActivityBarProviding,
        chat: DefaultChatSectionProviding,
        rootView: DefaultRootViewProviding,
        railView: DefaultRailViewProviding
    ) {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProviding()
        let railView = DefaultRailViewProviding()
        let storage = DefaultStorageProvider(dataRootDirectory: storageRoot)
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any StorageProviding).self, storage)
        return (kernel, activityBar, chat, rootView, railView)
    }

    /// 注册 Explorer + Chats 两个 tab，order 与生产一致
    /// （Explorer 30、Chats 81），使回退项确定是 Explorer。
    private func registerExplorerAndChats(_ railView: DefaultRailViewProviding) {
        railView.registerTabs([
            RailTabItem(
                id: "explorer",
                category: .fileTree,
                title: "Explorer",
                systemImage: "folder",
                order: 30
            ) { AnyView(EmptyView()) },
            RailTabItem(
                id: "chats",
                category: .chat,
                title: "Chats",
                systemImage: "bubble.left",
                order: 81
            ) { AnyView(EmptyView()) },
        ])
    }

    @Test("切回 Chat 时恢复离开前选择的 Chats，不被临时回退项覆盖")
    func reactivatingChatRestoresChatsNotFallbackTab() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelRailRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let (kernel, activityBar, _, _, railView) = try makeEnvironment(storageRoot: storageRoot)
        registerExplorerAndChats(railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // 用户在 Chat 里选择 Chats —— 这应当被保存为 Rail 偏好。
        railView.activateTab(id: "chats")
        #expect(railView.activeTabID == "chats")

        // 切到独立插件：它把 Rail 可见分类收窄到自己的分类，
        // 于是 Chats 不再可见（生产链路见 PluginGitWorkspace 等）。
        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID,
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)
        railView.setVisibleCategories([.project])
        #expect(railView.activeTabID != "chats", "离开 Chat 后原标签不再可见")

        // 切回 Chat：Chat 把可见分类收窄回 [.chat, .fileTree]，
        // 此时必须恢复 Chats，而不是可见分类里的第一个回退项（Explorer）。
        activityBar.activateItem(id: plugin.id + ".entry")

        #expect(
            railView.activeTabID == "chats",
            """
            切回 Chat 后选中的是 \(railView.activeTabID ?? "nil")，\
            期望恢复成 "chats"。\
            可见分类切换产生的临时回退项被当成了用户选择并覆盖了偏好。
            """
        )
        try plugin.onShutdown(kernel: kernel)
    }

    /// 偏好文件里存的必须是用户真正选过的标签。
    ///
    /// 这条从存储层锁住根因：临时回退项不该被持久化。
    @Test("可见分类切换产生的临时回退项不得写入偏好存储")
    func fallbackTabIsNotPersisted() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelRailPersist-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let (kernel, activityBar, _, _, railView) = try makeEnvironment(storageRoot: storageRoot)
        registerExplorerAndChats(railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        // 用户选择 Chats。
        railView.activateTab(id: "chats")

        // 切走再切回。
        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID,
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)
        railView.setVisibleCategories([.project])
        activityBar.activateItem(id: plugin.id + ".entry")

        // 偏好存储里必须是 "chats"，不能是回退项 "explorer"。
        let store = FileRailActiveTabStore(
            fileURL: DefaultStorageProvider(dataRootDirectory: storageRoot)
                .pluginDataDirectory(for: ChatPanelPlugin().id)
                .appendingPathComponent("rail-active-tab.plist")
        )
        #expect(
            store.load() == "chats",
            """
            偏好存储里是 \(store.load() ?? "nil")，期望 "chats"。\
            临时回退项覆盖了用户的选择。
            """
        )
        try plugin.onShutdown(kernel: kernel)
    }
    /// 恢复流程结束后，偏好仍应指向用户选择的标签。
    ///
    /// 这条锁住「恢复动作本身会触发 `activeTabChanged`」这条链路 ——
    /// 恢复不能被当成新的用户选择，但恢复后的稳定状态必须被记下来。
    @Test("恢复后偏好仍然指向用户选择的标签")
    func preferenceRemainsUserSelectionAfterRestore() throws {
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatPanelRailKeep-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let (kernel, activityBar, _, _, railView) = try makeEnvironment(storageRoot: storageRoot)
        registerExplorerAndChats(railView)

        let plugin = ChatPanelPlugin()
        try plugin.onBoot(kernel: kernel)

        railView.activateTab(id: "chats")

        let otherEntryID = "test.other.entry"
        activityBar.addItems([ActivityBarItem(
            id: otherEntryID,
            title: "Other",
            systemImage: "square"
        )])
        activityBar.activateItem(id: otherEntryID)
        railView.setVisibleCategories([.project])
        activityBar.activateItem(id: plugin.id + ".entry")

        // 再切一次，验证恢复是稳定的（不会来回漂移）。
        activityBar.activateItem(id: otherEntryID)
        railView.setVisibleCategories([.project])
        activityBar.activateItem(id: plugin.id + ".entry")

        #expect(railView.activeTabID == "chats", "反复切换后应稳定恢复 Chats")
        try plugin.onShutdown(kernel: kernel)
    }
}
