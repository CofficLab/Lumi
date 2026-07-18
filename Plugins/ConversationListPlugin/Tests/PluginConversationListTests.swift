import Foundation
import LumiCoreKit
import LumiCoreKit
import Testing
@testable import ConversationListPlugin

@Test func packageLoads() async throws {
    #expect(ConversationListPlugin.info.id == "com.coffic.lumi.plugin.conversation-list")
    #expect(ConversationListPlugin.info.displayName.isEmpty == false)
    #expect(ConversationListPlugin.info.description.isEmpty == false)
    #expect(ConversationListPlugin.iconName == "message.fill")
    #expect(ConversationListPlugin.category == .agent)
}

@MainActor
@Test func titleToolbarItemsRequireChatSectionAndService() throws {
    let hiddenChatContext = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        chatSection: .none
    )
    let visibleWithoutService = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        chatSection: .narrow
    )
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListToolbarTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: databaseDirectory), agentToolComponent: AgentToolComponent())
    let visibleWithService = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        chatSection: .narrow,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register((any LumiChatServicing).self, chatService)
        }
    )

    #expect(ConversationListPlugin.titleToolbarItems(context: hiddenChatContext).isEmpty)
    #expect(ConversationListPlugin.titleToolbarItems(context: visibleWithoutService).isEmpty)
    #expect(ConversationListPlugin.titleToolbarItems(context: visibleWithService).count == 1)
}

@MainActor
@Test func pluginRegistersProjectSwitchMiddleware() {
    let middlewares = ConversationListPlugin.sendMiddlewares(
        context: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    )
    #expect(middlewares.count == 1)
}

@MainActor
@Test func pluginRegistersConversationListToolsWhenChatServiceExists() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let chatService = try ChatService(
        configuration: .coreDatabase(directory: databaseDirectory)
    )
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register((any LumiChatServicing).self, chatService)
        }
    )
    let tools = ConversationListPlugin.agentTools(context: context)
    let toolNames = Set(tools.map(\.name))

    #expect(toolNames.contains("create_new_conversation"))
    #expect(toolNames.contains("delete_conversation"))
    #expect(toolNames.contains("get_recent_conversations"))
    #expect(toolNames.contains("get_conversation_count"))
    #expect(toolNames.contains("set_conversation_project"))
}

@MainActor
@Test func pluginProvidesChatRailTabWhenShowsRail() {
    let hidden = ConversationListPlugin.panelRailTabItems(
        context: LumiPluginContext(
            activeSectionID: ChatPanelSection.id,
            activeSectionTitle: "Chat"
        )
    )
    #expect(hidden.isEmpty)

    let withoutService = ConversationListPlugin.panelRailTabItems(
        context: LumiPluginContext(
            activeSectionID: ChatPanelSection.id,
            activeSectionTitle: "Chat",
            showsRail: true
        )
    )
    #expect(withoutService.isEmpty)
}

@MainActor
@Test func pluginIgnoresEditorSectionForRailTabs() {
    let tabs = ConversationListPlugin.panelRailTabItems(
        context: LumiPluginContext(
            activeSectionID: "LumiEditor",
            activeSectionTitle: "Editor",
            showsRail: true
        )
    )
    #expect(tabs.isEmpty)
}

@Test func localStoreSavesAndReloadsSelectedConversationId() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let selectedId = UUID()
    let store = ConversationListLocalStore(settingsDirectory: directory)

    #expect(store.saveSelectedConversationId(selectedId) == true)

    let reloadedStore = ConversationListLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.loadSelectedConversationId() == selectedId)
}

@Test func localStoreQuarantinesInvalidSelectionFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let selectionURL = directory.appendingPathComponent("conversation_selection.plist")
    let corruptURL = directory.appendingPathComponent("conversation_selection.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: selectionURL)

    let selectedId = UUID()
    let store = ConversationListLocalStore(settingsDirectory: directory)

    #expect(store.saveSelectedConversationId(selectedId) == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.loadSelectedConversationId() == selectedId)

    let reloadedStore = ConversationListLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.loadSelectedConversationId() == selectedId)
}

@Test func localStoreReportsFailureWhenSelectionDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = ConversationListLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.saveSelectedConversationId(UUID()) == false)
    #expect(store.loadSelectedConversationId() == nil)
}
