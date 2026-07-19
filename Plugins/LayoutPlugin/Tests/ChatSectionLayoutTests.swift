import Foundation
import LumiKernel
import SwiftUI
import Testing
@testable import LayoutPlugin

@Test func localStorePersistsRightSidebarVisibility() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-RightSidebar-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    store.saveRightSidebarVisible(false)

    #expect(store.loadRightSidebarVisible() == false)
}

@MainActor
@Test func layoutStateBindsChatSectionVisibility() {
    let layoutState = LumiLayoutState()
    #expect(layoutState.chatSectionVisible == true)
    layoutState.chatSectionVisible = false
    #expect(layoutState.chatSectionVisible == false)
}
