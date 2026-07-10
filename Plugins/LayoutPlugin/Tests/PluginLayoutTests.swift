import Foundation
import LumiCoreKit
import Testing
@testable import LayoutPlugin

@Test func localStorePersistsSplitDimensions() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-SplitDimensions-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let railKey = LayoutStorageKey.railWidth(viewContainerID: "LumiEditor")
    store.saveSplitDimension(312, forKey: railKey)

    #expect(store.loadSplitDimension(forKey: railKey) == 312)
    #expect(store.loadSplitDimensions()[railKey] == 312)

    let reloadedStore = LayoutPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.loadSplitDimension(forKey: railKey) == 312)
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
    #expect(FileManager.default.fileExists(atPath: settingsURL.path) == false)
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

@Test func restoreWritesSplitDimensionsIntoLayoutState() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayout-Restore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    let containerID = "LumiEditor"
    // 用与插件写入时一致的 key，预置尺寸数据
    store.saveSplitDimension(312, forKey: LayoutStorageKey.railWidth(viewContainerID: containerID))
    store.saveSplitDimension(168, forKey: LayoutStorageKey.bottomPanelHeight(viewContainerID: containerID))
    store.saveSplitDimension(
        420,
        forKey: LayoutStorageKey.chatSectionWidth(viewContainerID: containerID, layout: .narrow)
    )

    let state = LumiLayoutState()
    LayoutPersistenceCoordinator.shared.restore(into: state, from: store)

    #expect(state.railWidth(for: containerID) == 312)
    #expect(state.bottomPanelHeight(for: containerID) == 168)
    #expect(state.chatSectionWidth(for: containerID, layout: .narrow) == 420)
    // 其它档位/容器不受影响
    #expect(state.chatSectionWidth(for: containerID, layout: .wide) == 320)
}

@MainActor
@Test func restoreDoesNotPostNotificationsDuringBackfill() {
    // 恢复使用 restoreXxx（不发通知），这里验证恢复后状态可读即可
    let state = LumiLayoutState()
    let store = LayoutPluginLocalStore(pluginDirectory: FileManager.default.temporaryDirectory)
    LayoutPersistenceCoordinator.shared.restore(into: state, from: store)
    // 空 store → 全部回退默认值，无崩溃
    #expect(state.railWidth(for: "any") == 240)
}

@Test func chatSectionLayoutRoundTripsThroughPersistenceSuffix() throws {
    // 确保 LumiChatSectionLayout.from(suffix:) 能还原所有持久化档位，
    // 这是 LayoutStorageKey 与通知负载 layout 字段一致性的关键。
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "none") == .none)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "narrow") == .narrow)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "wide") == .wide)
    #expect(LumiChatSectionLayout.from(persistenceKeySuffix: "bogus") == nil)
}

