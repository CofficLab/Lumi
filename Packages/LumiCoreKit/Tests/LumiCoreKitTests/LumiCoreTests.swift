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
        showsChatSection: true
    )

    let plugins: [any LumiPlugin.Type] = [SecondPlugin.self, FirstPlugin.self]
    let items = plugins
        .flatMap { $0.chatSectionItems(context: context) }
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
