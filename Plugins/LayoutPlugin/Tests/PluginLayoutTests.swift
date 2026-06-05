import Foundation
import LumiCoreKit
import SwiftUI
import Testing
@testable import LayoutPlugin

@MainActor
@Test
func toolbarViewRequiresLayoutControlCapability() {
    let context = PluginContext(
        activeIcon: "bubble.left.and.bubble.right.fill",
        layoutControlContext: LayoutControlContext(
            editorVisible: .constant(true),
            contentPanelVisible: .constant(true),
            bottomPanelVisible: .constant(false),
            railVisible: .constant(true),
            rightSidebarVisible: .constant(true)
        )
    )
    let missingCapabilityContext = PluginContext(activeIcon: "bubble.left.and.bubble.right.fill")
    let hiddenContext = PluginContext(activeIcon: "sidebar")

    #expect(LayoutPlugin.shared.addToolBarTrailingView(context: context) != nil)
    #expect(LayoutPlugin.shared.addToolBarTrailingView(context: missingCapabilityContext) == nil)
    #expect(LayoutPlugin.shared.addToolBarTrailingView(context: hiddenContext) == nil)
}

@Test
func localStorePersistsLayoutSettings() throws {
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

@Test
func localStoreQuarantinesCorruptSettingsAndRecovers() throws {
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
