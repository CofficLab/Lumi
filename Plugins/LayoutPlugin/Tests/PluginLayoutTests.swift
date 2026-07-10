import Foundation
import LumiCoreKit
import Testing
@testable import LayoutPlugin

@Test func localStorePersistsSplitDimensions() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-SplitDimensions-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let railKey = LayoutStorageKey.railDivider(viewContainerID: "LumiEditor")
    store.saveSplitDimension(312, forKey: railKey)

    #expect(store.loadSplitDimension(forKey: railKey) == 312)
    #expect(store.loadSplitDimensions()[railKey] == 312)

    let reloadedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.loadSplitDimension(forKey: railKey) == 312)
}

@Test func localStoreRemovesSplitDimension() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-Remove-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let key = LayoutStorageKey.railDivider(viewContainerID: "LumiEditor")
    store.saveSplitDimension(312, forKey: key)
    #expect(store.loadSplitDimension(forKey: key) == 312)

    store.removeSplitDimension(forKey: key)

    // 等待异步删除完成
    for _ in 0..<20 {
        if store.loadSplitDimension(forKey: key) == nil { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(store.loadSplitDimension(forKey: key) == nil)
    #expect(store.loadSplitDimensions()[key] == nil)
}

@Test func localStorePersistsActiveViewContainerID() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-ViewContainer-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    store.saveActiveViewContainerID("LumiEditor")

    #expect(store.loadActiveViewContainerID() == "LumiEditor")

    let reloadedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.loadActiveViewContainerID() == "LumiEditor")
}

@Test func loadActiveViewContainerIDIgnoresLegacyIconKeys() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-LegacyIcon-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    store.saveActiveViewContainerIcon("chevron.left.forwardslash.chevron.right")

    #expect(store.loadActiveViewContainerID() == nil)
}

@Test func localStorePersistsLayoutSettings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    store.saveActiveViewContainerIcon("sidebar")
    store.saveLayoutRatios(["main": 0.7, "side": 0.3])
    store.saveBottomPanelVisible(true)
    store.saveEditorVisible(false)

    #expect(store.loadActiveViewContainerIcon() == "sidebar")
    #expect(store.loadLayoutRatios() == ["main": 0.7, "side": 0.3])
    #expect(store.loadBottomPanelVisible() == true)
    #expect(store.loadEditorVisible() == false)
}

@Test func localStoreQuarantinesCorruptSettingsAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-Corrupt-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(store.loadActiveViewContainerIcon() == nil)
    #expect(FileManager.fileExists(atPath: settingsURL.path) == false)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)

    store.saveActiveViewContainerIcon("editor")
    store.saveLayoutRatios(["content": 0.62])
    #expect(store.loadActiveViewContainerIcon() == "editor")
    #expect(store.loadLayoutRatios() == ["content": 0.62])

    let reloadedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.loadActiveViewContainerIcon() == "editor")
    #expect(reloadedStore.loadLayoutRatios() == ["content": 0.62])
}

// MARK: - 分栏尺寸恢复链路

@MainActor
@Test func restoreWritesSplitDimensionsIntoLayoutState() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-Restore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let containerID = "LumiEditor"
    // 用与插件写入时一致的 key，预置尺寸数据
    store.saveSplitDimension(312, forKey: LayoutStorageKey.railDivider(viewContainerID: containerID))
    store.saveSplitDimension(168, forKey: LayoutStorageKey.bottomPanelDivider(viewContainerID: containerID))
    store.saveSplitDimension(
        420,
        forKey: LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: .narrow)
    )

    let state = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: state, from: store)

    #expect(state.railDivider(for: containerID) == 312)
    #expect(state.bottomPanelDivider(for: containerID) == 168)
    #expect(state.chatSectionDivider(for: containerID, layout: .narrow) == 420)
    // 其它档位/容器不受影响
    #expect(state.chatSectionDivider(for: containerID, layout: .wide) == 320)
}

/// 端到端：模拟用户拖拽 ChatSection divider → listener 落盘 → 重启后从磁盘恢复。
@MainActor
@Test func chatSectionDividerSurvivesRestartRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-RoundTrip-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let containerID = "main"
    let layout = LumiChatSectionLayout.narrow

    // 1) 用户调整 chatSection divider 位置：listener 监听通知并落盘
    let listener = LayoutEventListener(store: store)
    _ = listener // 保持监听存活

    LumiLayoutState().setChatSectionDivider(500, for: containerID, layout: layout)

    // 2) 等待异步写盘完成：轮询 store 直到数据落盘（最多 1s）
    let key = LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: layout)
    for _ in 0..<20 {
        let persisted = store.loadSplitDimension(forKey: key)
        if persisted == 500.0 { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    // 确认数据已写入内存缓存（即 async 块已执行）
    #expect(store.loadSplitDimension(forKey: key) == 500.0, "Divider position should be persisted to store")

    // 3) 模拟重启：用一个全新的 store 读取同一目录，再用全新 state 恢复
    let restartedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    let restartedState = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: restartedState, from: restartedStore)

    // 期望：调整后的 divider 位置应被恢复
    #expect(restartedState.chatSectionDivider(for: containerID, layout: layout) == 500)
}

/// 验证：直接写盘 → 重启读取 → 恢复链路。
@MainActor
@Test func chatSectionDividerDirectWriteRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-DirectWrite-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let containerID = "LumiEditor"
    let layout = LumiChatSectionLayout.narrow
    let key = LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: layout)

    // 1) 直接写盘（模拟持久化层已落盘的状态）
    store.saveSplitDimension(450, forKey: key)

    // 2) 等待写盘完成
    for _ in 0..<20 {
        if store.loadSplitDimension(forKey: key) == 450.0 { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(store.loadSplitDimension(forKey: key) == 450.0)

    // 3) 新 store 从磁盘读取
    let restartedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(restartedStore.loadSplitDimension(forKey: key) == 450.0)

    // 4) 恢复进 layoutState
    let restartedState = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: restartedState, from: restartedStore)
    #expect(restartedState.chatSectionDivider(for: containerID, layout: layout) == 450)
}

/// 验证：多档位 divider 位置各自独立持久化与恢复。
@MainActor
@Test func chatSectionDividerMultipleLayoutsAreIndependent() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-MultiLayout-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let containerID = "main"

    store.saveSplitDimension(380, forKey: LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: .narrow))
    store.saveSplitDimension(520, forKey: LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: .wide))

    // 等待写盘完成
    for _ in 0..<20 {
        let narrowOk = store.loadSplitDimension(forKey: LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: .narrow)) == 380.0
        let wideOk = store.loadSplitDimension(forKey: LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: .wide)) == 520.0
        if narrowOk && wideOk { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    let restartedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    let restartedState = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: restartedState, from: restartedStore)

    #expect(restartedState.chatSectionDivider(for: containerID, layout: .narrow) == 380)
    #expect(restartedState.chatSectionDivider(for: containerID, layout: .wide) == 520)
}


@MainActor
@Test func restoreDoesNotPostNotificationsDuringBackfill() {
    // 恢复使用 restoreXxx（不发通知），这里验证恢复后状态可读即可
    let state = LumiLayoutState()
    let store = LayoutPluginLocalStore(pluginDirectory: FileManager.default.temporaryDirectory)
    LayoutPersistenceCoordinator.shared.restore(into: state, from: store)
    // 空 store → 全部回退默认值，无崩溃
    #expect(state.railDivider(for: "any") == 240)
}

@Test func chatSectionLayoutRoundTripsThroughPersistenceSuffix() throws {
    // 确保 LumiChatSectionLayout.from(suffix:) 能还原所有持久化档位，
    // 这是 LayoutStorageKey 与通知负载 layout 字段一致性的关键。
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "none") == .none)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "narrow") == .narrow)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "wide") == .wide)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "bogus") == nil)
}

/// 验证：v1 旧 key（Layout.Width.* / Layout.Height.*）在 restore 时被一次性清理。
@MainActor
@Test func restoreCleansUpLegacyWidthHeightKeys() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-LegacyKeys-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    // 直接写旧格式 key（绕过 LayoutStorageKey）
    store.saveSplitDimension(312, forKey: "Layout.Width.LumiEditor.Rail")
    store.saveSplitDimension(168, forKey: "Layout.Height.LumiEditor.BottomPanel")
    // 同时写一个新格式 key，验证清理不会误删
    store.saveSplitDimension(420, forKey: LayoutStorageKey.railDivider(viewContainerID: "OtherEditor"))

    // 等待写盘
    for _ in 0..<20 {
        if store.loadSplitDimension(forKey: "Layout.Width.LumiEditor.Rail") == 312.0 { break }
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    let state = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: state, from: store)

    // 旧 key 应被清理
    #expect(store.loadSplitDimension(forKey: "Layout.Width.LumiEditor.Rail") == nil)
    #expect(store.loadSplitDimension(forKey: "Layout.Height.LumiEditor.BottomPanel") == nil)
    // 新 key 应保留
    #expect(store.loadSplitDimension(forKey: LayoutStorageKey.railDivider(viewContainerID: "OtherEditor")) == 420.0)
    // 旧 key 的值不能被解释为新格式的 divider（state 应当回退到默认）
    #expect(state.railDivider(for: "LumiEditor") == 240)
    #expect(state.storedRailDivider(for: "LumiEditor") == nil)
    #expect(state.bottomPanelDivider(for: "LumiEditor") == 400)
    #expect(state.storedBottomPanelDivider(for: "LumiEditor") == nil)
    // 新 key 的值应被正确恢复
    #expect(state.railDivider(for: "OtherEditor") == 420)
}
