import Testing
import Foundation
import AppKit
import SwiftUI
import KernelCore
import KitTestIsolation
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderStorage
@testable import InputPlugin
@testable import ProviderRootView

@MainActor
@Test func packageLoads() async throws {
    let plugin = InputPlugin()

    #expect(plugin.id == "com.coffic.lumi.plugin.input-manager")
    #expect(plugin.metadata.policy == .disabledByDefault)
}

@MainActor
@Test func activatingPluginHidesRailAndContentHeaderAndDeactivatingRestoresThem() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let contentView = DefaultContentViewProviding()
    let railView = DefaultRailViewProviding()
    let rootView = DefaultRootViewProviding()
    rootView.setRailView(railView.makeRailView())
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ContentViewProviding).self, contentView)
    try kernel.registerProvider((any RailViewProviding).self, railView)
    try kernel.registerProvider((any RootViewProviding).self, rootView)
    // 存储 Provider 决定插件数据目录。测试进程里守卫拒绝回退到本机真实目录，
    // 因此 boot 必须能拿到真实（临时目录）Provider 才能继续。
    try kernel.registerProvider(
        (any StorageProviding).self,
        InputPluginTestDoubles.StubStorageProvider(
            root: InputPluginTestDoubles.makeTemporaryDirectory("activation")
        )
    )

    let plugin = InputPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(!chat.isVisible)
    #expect(rootView.railView == nil)
    #expect(rootView.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
    #expect(rootView.railView != nil)
    #expect(rootView.isContentHeaderViewHidden == false)
}

@MainActor
@Test func compactHostActivatesAndRestoresRailLifecycleWithoutActivityBar() throws {
    let kernel = KernelCoreContainer()
    let chat = DefaultChatSectionProviding()
    let contentView = DefaultContentViewProviding()
    let railView = DefaultRailViewProviding()
    let rootView = DefaultRootViewProviding()
    railView.addTabs([
        RailTabItem(id: "files", category: .fileTree, title: "Files", systemImage: "folder") {
            Text("Files")
        },
    ])
    rootView.setRailView(railView.makeRailView())
    rootView.setRailViewVisible(true)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ContentViewProviding).self, contentView)
    try kernel.registerProvider((any RailViewProviding).self, railView)
    try kernel.registerProvider((any RootViewProviding).self, rootView)
    // 存储 Provider 决定插件数据目录。测试进程里守卫拒绝回退到本机真实目录，
    // 因此 boot 必须能拿到真实（临时目录）Provider 才能继续。
    try kernel.registerProvider(
        (any StorageProviding).self,
        InputPluginTestDoubles.StubStorageProvider(
            root: InputPluginTestDoubles.makeTemporaryDirectory("compact-host")
        )
    )

    let plugin = InputPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(!chat.isVisible)
    #expect(rootView.railView == nil)
    #expect(!rootView.isRailViewVisible)
    #expect(rootView.isContentHeaderViewHidden)

    try plugin.onShutdown(kernel: kernel)

    #expect(chat.isVisible)
    #expect(rootView.railView != nil)
    #expect(rootView.isRailViewVisible)
    #expect(!rootView.isContentHeaderViewHidden)
}

@MainActor
@Test func localStoreReportsSaveResultAndReloadsData() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = InputPluginLocalStore(pluginDirectory: directory)
    let data = Data("rule-config".utf8)

    #expect(store.set(data, forKey: "InputPluginConfig") == true)

    let reloadedStore = InputPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.data(forKey: "InputPluginConfig") == data)
}

@MainActor
@Test func localStoreUsesPluginRootWithoutNestedSettingsDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Root-\(UUID().uuidString)", isDirectory: true)
    defer {
        InputPluginRuntimeBridge.dataRootDirectory = nil
        InputPluginRuntimeBridge.pluginDirectory = nil
        try? FileManager.default.removeItem(at: root)
    }

    InputPluginRuntimeBridge.dataRootDirectory = root
    InputPluginRuntimeBridge.pluginDirectory = root.appendingPathComponent(
        "com.coffic.lumi.plugin.input-manager",
        isDirectory: true
    )
    let store = InputPluginLocalStore()
    #expect(store.set(Data("rule-config".utf8), forKey: "InputPluginConfig") == true)

    let pluginDirectory = root.appendingPathComponent(
        "com.coffic.lumi.plugin.input-manager",
        isDirectory: true
    )
    #expect(FileManager.default.fileExists(atPath: pluginDirectory.appendingPathComponent("settings.plist").path))
    #expect(!FileManager.default.fileExists(atPath: pluginDirectory.appendingPathComponent("settings", isDirectory: true).path))
}

@MainActor
@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = InputPluginLocalStore(pluginDirectory: directory)
    let newData = Data("new config".utf8)

    #expect(store.set(newData, forKey: "InputPluginConfig") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.data(forKey: "InputPluginConfig") == newData)

    let reloadedStore = InputPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.data(forKey: "InputPluginConfig") == newData)
}

@MainActor
@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = InputPluginLocalStore(pluginDirectory: blockedDirectory)

    #expect(store.set(Data("rule-config".utf8), forKey: "InputPluginConfig") == false)
    #expect(store.data(forKey: "InputPluginConfig") == nil)
}

/// 回归 #784：旧版本嵌套的 settings/settings.plist 必须在首次启动时前移，
/// 否则通用迁移只拷贝目录、当前存储只读根文件，旧规则与偏好被静默丢弃。
@Test func localStoreMigratesLegacyNestedSettingsOnFirstRead() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Legacy-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let legacyDirectory = directory.appendingPathComponent("settings", isDirectory: true)
    try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
    let legacyURL = legacyDirectory.appendingPathComponent("settings.plist")
    let configData = Data("legacy-rule-config".utf8)
    let plist: [String: Any] = ["InputPluginConfig": configData]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        .write(to: legacyURL)

    let store = InputPluginLocalStore(pluginDirectory: directory)

    #expect(store.data(forKey: "InputPluginConfig") == configData)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.plist").path))
    #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
}

/// 护栏 #784：根文件已存在时不得用旧嵌套文件覆盖它，旧文件原样保留。
@Test func localStoreKeepsExistingFlatSettingsOverLegacyNested() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-LegacyGuard-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let flatURL = directory.appendingPathComponent("settings.plist")
    let newData = Data("new-rule-config".utf8)
    try PropertyListSerialization.data(fromPropertyList: ["InputPluginConfig": newData], format: .binary, options: 0)
        .write(to: flatURL)

    let legacyDirectory = directory.appendingPathComponent("settings", isDirectory: true)
    try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
    let legacyURL = legacyDirectory.appendingPathComponent("settings.plist")
    let oldData = Data("old-rule-config".utf8)
    try PropertyListSerialization.data(fromPropertyList: ["InputPluginConfig": oldData], format: .binary, options: 0)
        .write(to: legacyURL)

    let store = InputPluginLocalStore(pluginDirectory: directory)

    #expect(store.data(forKey: "InputPluginConfig") == newData)
    #expect(FileManager.default.fileExists(atPath: legacyURL.path))
}

/// 回归 #784：迁移后的配置可继续保存并跨重启读取，旧嵌套文件不再残留。
@Test func localStoreMigratedSettingsSurviveReloadAndSave() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-LegacyReload-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let legacyDirectory = directory.appendingPathComponent("settings", isDirectory: true)
    try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
    let legacyURL = legacyDirectory.appendingPathComponent("settings.plist")
    let configData = Data("legacy-rule-config".utf8)
    try PropertyListSerialization.data(fromPropertyList: ["InputPluginConfig": configData], format: .binary, options: 0)
        .write(to: legacyURL)

    let store = InputPluginLocalStore(pluginDirectory: directory)
    #expect(store.data(forKey: "InputPluginConfig") == configData)

    let updated = Data("updated-rule-config".utf8)
    #expect(store.set(updated, forKey: "InputPluginConfig") == true)

    let reloaded = InputPluginLocalStore(pluginDirectory: directory)
    #expect(reloaded.data(forKey: "InputPluginConfig") == updated)
    #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
}

@MainActor
@Test func refreshingSettingsReloadsInputSources() {
    // InputSettingsViewModel 会触碰 InputService.shared，进而读取插件数据目录。
    // 测试进程里守卫拒绝回退到本机真实目录，因此必须先注入临时目录。
    InputPluginRuntimeBridge.pluginDirectory = InputPluginTestDoubles.makeTemporaryDirectory("refresh-sources")
    defer { InputPluginRuntimeBridge.pluginDirectory = nil }

    let viewModel = InputSettingsViewModel()
    let stale = InputSource(
        id: "stale.input.source",
        name: "Stale",
        category: "TISCategoryKeyboardInputSource",
        isSelectable: true
    )
    viewModel.apply(availableSources: [stale])

    viewModel.refreshSources()

    // 刷新必须重新枚举系统输入源，而不是复用启动时缓存的列表。
    #expect(!viewModel.availableSources.contains(stale))
    #expect(
        viewModel.availableSources.map(\.id)
            == InputService.shared.availableInputSources.map(\.id)
    )
}

@MainActor
@Test func removeRuleIgnoresStaleOffsets() {
    // InputSettingsViewModel 会触碰 InputService.shared，进而读取插件数据目录。
    // 测试进程里守卫拒绝回退到本机真实目录，因此必须先注入临时目录。
    InputPluginRuntimeBridge.pluginDirectory = InputPluginTestDoubles.makeTemporaryDirectory("remove-rule")
    defer { InputPluginRuntimeBridge.pluginDirectory = nil }

    let viewModel = InputSettingsViewModel()
    viewModel.rules = [
        InputRule(appBundleID: "com.example.one", appName: "One", inputSourceID: "source.one")
    ]

    viewModel.removeRule(at: IndexSet([2]))

    #expect(viewModel.rules.count == 1)
}

@MainActor
@Test func launchAndTerminateNotificationsRefreshRunningApps() async throws {
    // InputSettingsViewModel 会触碰 InputService.shared，进而读取插件数据目录。
    // 测试进程里守卫拒绝回退到本机真实目录，因此必须先注入临时目录。
    InputPluginRuntimeBridge.pluginDirectory = InputPluginTestDoubles.makeTemporaryDirectory("running-apps-notify")
    defer { InputPluginRuntimeBridge.pluginDirectory = nil }

    let center = NSWorkspace.shared.notificationCenter
    var providerCalls = 0
    // 注入可枚举的来源只为计数：通知到达时 refreshRunningApps 必须重新拉取，
    // 否则页面常驻期间启动/退出的应用不会出现在选择器里（#785）。
    let viewModel = InputSettingsViewModel(runningAppsProvider: {
        providerCalls += 1
        return []
    })
    let callsAfterInit = providerCalls

    center.post(name: NSWorkspace.didLaunchApplicationNotification, object: nil)
    let launched = await waitUntilRunningAppsRefreshed { providerCalls > callsAfterInit }
    #expect(launched)

    let callsAfterLaunch = providerCalls
    center.post(name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    let terminated = await waitUntilRunningAppsRefreshed { providerCalls > callsAfterLaunch }
    #expect(terminated)
}

/// 观察者块经主队列异步投递：轮询等待其落地。
@MainActor
private func waitUntilRunningAppsRefreshed(
    timeout: Duration = .seconds(1),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

// MARK: - 运行时目录

/// 运行时目录守卫的测试。
///
/// `InputPluginRuntimeBridge.resolvedPluginDirectory` 在测试进程里未注入即拒绝
/// （`fatalError`，直接终止整个测试进程），因此这里既不能依赖生产回退目录，
/// 也不能让注入状态在用例之间互相污染。
///
/// 所有涉及注入状态的用例都标注 `@MainActor` 且不同步挂起：MainActor 是串行
/// 执行器，这些用例因此不会并发读写同一份进程级注入状态。
@Suite("Input 运行时目录", .serialized)
@MainActor
struct InputPluginRuntimeTests {

    @Test("注入目录后 resolvedPluginDirectory 返回该目录")
    func usesInjectedDirectory() {
        let directory = InputPluginTestDoubles.makeTemporaryDirectory("runtime-injected")
        InputPluginRuntimeBridge.pluginDirectory = directory
        defer { InputPluginRuntimeBridge.pluginDirectory = nil }

        #expect(InputPluginRuntimeBridge.resolvedPluginDirectory == directory)
    }

    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func refusesWithoutInjectedDirectory() {
        InputPluginRuntimeBridge.pluginDirectory = nil

        #expect(InputPluginRuntimeBridge.pluginDirectory == nil)

        // 未注入时不得回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: InputPluginRuntimeBridge.pluginDirectory,
            owner: "InputPluginRuntimeBridge",
            accessor: "resolvedPluginDirectory",
            fallback: { URL(fileURLWithPath: "/tmp/input-plugin-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("InputPluginRuntimeBridge"))
            #expect(reason.contains("resolvedPluginDirectory"))
        }
    }

    @Test("启动时把存储目录注入运行时配置")
    func bootInjectsStorageDirectory() throws {
        let root = InputPluginTestDoubles.makeTemporaryDirectory("runtime-boot")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            InputPluginTestDoubles.StubStorageProvider(root: root)
        )

        let plugin = InputPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { InputPluginRuntimeBridge.pluginDirectory = nil }

        #expect(
            InputPluginRuntimeBridge.resolvedPluginDirectory
                == root.appendingPathComponent("com.coffic.lumi.plugin.input-manager", isDirectory: true)
        )
    }
}

/// 回归 #365：运行时禁用只走 `onDisable`（内核不调用 `onShutdown`）。
/// 此前 InputPlugin 没有 `onDisable`，`InputEventObserver` 仍订阅应用激活通知
/// 并转发给 `InputService.handleAppActivation`，禁用后仍按旧规则切换 macOS 输入源。
/// 禁用必须立即停止监听，启用时再恢复。
///
/// `InputService.shared` 与运行时目录注入是进程级共享状态，用 `.serialized`
/// 串行化并在 defer 中 shutdown 清理，避免影响并行套件。
@Suite("Input 禁用生命周期", .serialized)
@MainActor
struct InputDisableLifecycleTests {
    @Test func disableStopsAppActivationListenerAndEnableRestoresIt() async throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        let contentView = DefaultContentViewProviding()
        let railView = DefaultRailViewProviding()
        let rootView = DefaultRootViewProviding()
        rootView.setRailView(railView.makeRailView())
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any RailViewProviding).self, railView)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider(
            (any StorageProviding).self,
            InputPluginTestDoubles.StubStorageProvider(
                root: InputPluginTestDoubles.makeTemporaryDirectory("disable-lifecycle")
            )
        )

        let plugin = InputPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        let entry = "\(plugin.id).entry"
        // 启用后监听器在订阅系统通知，ActivityBar 入口存在。
        #expect(plugin.isEventObserverRunningForTesting)
        #expect(activityBar.items.contains { $0.id == entry })

        try await plugin.onDisable(kernel: kernel)

        // 禁用必须立即停止应用激活监听，不再切换输入源，并撤回入口。
        #expect(!plugin.isEventObserverRunningForTesting)
        #expect(!activityBar.items.contains { $0.id == entry })

        try await plugin.onEnable(kernel: kernel)

        // 重新启用后监听与入口恢复。
        #expect(plugin.isEventObserverRunningForTesting)
        #expect(activityBar.items.contains { $0.id == entry })
    }
}
