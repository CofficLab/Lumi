import Foundation
import LumiCoreKit
import SwiftUI
import Testing
@testable import LayoutPlugin

@Test func layoutControlContextBindsChatSectionVisibility() {
    var visible = true
    let context = LayoutControlContext(
        chatSectionVisible: Binding(
            get: { visible },
            set: { visible = $0 }
        )
    )

    #expect(context.chatSectionVisible.wrappedValue == true)
    context.chatSectionVisible.wrappedValue = false
    #expect(visible == false)
}

@Test func localStorePersistsRightSidebarVisibility() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginLayoutLocalStore-RightSidebar-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = LayoutPluginLocalStore(pluginDirectory: directory)
    store.saveRightSidebarVisible(false)

    #expect(store.loadRightSidebarVisible() == false)
}
