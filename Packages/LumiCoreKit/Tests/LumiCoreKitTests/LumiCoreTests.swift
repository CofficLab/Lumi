import Foundation
import LumiCoreKit
import SwiftUI
import Testing

@MainActor
@Test func chatSectionItemsSortByOrder() {
    struct FirstPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "first", displayName: "First", description: "", order: 10)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
            [LumiChatSectionItem(id: "first", order: 10) { Text("First") }]
        }
    }

    struct SecondPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "second", displayName: "Second", description: "", order: 20)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
            [LumiChatSectionItem(id: "second", order: 20) { Text("Second") }]
        }
    }

    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow
    )

    let plugins: [any LumiPlugin.Type] = [SecondPlugin.self, FirstPlugin.self]
    let items = plugins
        .flatMap { $0.chatSectionItems(context: context) }
        .sorted { $0.order < $1.order }

    #expect(items.map(\.id) == ["first", "second"])
}

@MainActor
@Test func panelHeaderItemsRespectShowsPanelChromeGuard() {
    struct HeaderPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "header", displayName: "Header", description: "", order: 70)
        static let policy = LumiPluginPolicy.alwaysOn
        static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
            guard context.showsPanelChrome else { return [] }
            return [LumiPanelHeaderItem(id: "header", order: 70) { Text("Header") }]
        }
    }

    let hidden = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    let visible = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true
    )

    #expect(HeaderPlugin.panelHeaderItems(context: hidden).isEmpty)
    #expect(HeaderPlugin.panelHeaderItems(context: visible).map(\.id) == ["header"])
}

@MainActor
@Test func panelBottomTabItemsSortByOrder() {
    struct FirstBottomPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "first-bottom", displayName: "First", description: "", order: 0)
        static let policy = LumiPluginPolicy.alwaysOn
        static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
            [
                LumiPanelBottomTabItem(
                    id: "first",
                    order: 0,
                    title: "First",
                    systemImage: "1.circle"
                ) { Text("First") }
            ]
        }
    }

    struct SecondBottomPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "second-bottom", displayName: "Second", description: "", order: 1)
        static let policy = LumiPluginPolicy.alwaysOn
        static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
            [
                LumiPanelBottomTabItem(
                    id: "second",
                    order: 1,
                    title: "Second",
                    systemImage: "2.circle"
                ) { Text("Second") }
            ]
        }
    }

    let context = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true
    )

    let plugins: [any LumiPlugin.Type] = [SecondBottomPlugin.self, FirstBottomPlugin.self]
    let items = plugins
        .flatMap { $0.panelBottomTabItems(context: context) }
        .sorted { $0.order < $1.order }

    #expect(items.map(\.id) == ["first", "second"])
}

@MainActor
@Test func pluginDataDirectoryUsesSanitizedNameUnderConfiguredRoot() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    LumiCore.configure(dataRootDirectory: root)

    let directory = LumiCore.pluginDataDirectory(for: "Projects Plugin!")

    #expect(directory == root.appendingPathComponent("Projects_Plugin", isDirectory: true))
    #expect(FileManager.default.fileExists(atPath: directory.path))

    try? FileManager.default.removeItem(at: root)
}

@Test func chatSectionLayoutsShareResizeBoundsButKeepDistinctDefaults() {
    #expect(LumiChatSectionLayout.narrow.minWidth == LumiChatSectionLayout.wide.minWidth)
    #expect(LumiChatSectionLayout.narrow.maximumWidth == LumiChatSectionLayout.wide.maximumWidth)
    #expect(LumiChatSectionLayout.narrow.minimumRemainingWidth == LumiChatSectionLayout.wide.minimumRemainingWidth)
    #expect(LumiChatSectionLayout.narrow.defaultWidth == 320)
    #expect(LumiChatSectionLayout.wide.defaultWidth == 480)
}
