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
@Test func chatSectionToolbarBarItemsSortByOrder() {
    struct FirstPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "first", displayName: "First", description: "", order: 10)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
            [LumiChatSectionToolbarBarItem(id: "first", order: 10) { Text("First") }]
        }
    }

    struct SecondPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "second", displayName: "Second", description: "", order: 20)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
            [LumiChatSectionToolbarBarItem(id: "second", order: 20) { Text("Second") }]
        }
    }

    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow,
        isChatSectionVisible: true
    )

    let plugins: [any LumiPlugin.Type] = [SecondPlugin.self, FirstPlugin.self]
    let items = plugins
        .flatMap { $0.chatSectionToolbarBarItems(context: context) }
        .sorted { $0.order < $1.order }

    #expect(items.map(\.id) == ["first", "second"])
}

@MainActor
@Test func chatSectionHeaderItemsSortByOrder() {
    struct FirstPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "first", displayName: "First", description: "", order: 10)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
            [LumiChatSectionHeaderItem(id: "first", order: 10) { Text("First") }]
        }
    }

    struct SecondPlugin: LumiPlugin {
        static let info = LumiPluginInfo(id: "second", displayName: "Second", description: "", order: 20)
        static let policy = LumiPluginPolicy.alwaysOn
        static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
            [LumiChatSectionHeaderItem(id: "second", order: 20) { Text("Second") }]
        }
    }

    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow,
        isChatSectionVisible: true
    )

    let plugins: [any LumiPlugin.Type] = [SecondPlugin.self, FirstPlugin.self]
    let items = plugins
        .flatMap { $0.chatSectionHeaderItems(context: context) }
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

@MainActor
@Test func pluginContextExposesChatSectionVisibilityAndActiveProvider() {
    final class MockChatService: LumiChatServicing {
        var conversations: [LumiConversationSummary] = []
        var selectedConversationID: UUID? = UUID()
        var providerInfos: [LumiLLMProviderInfo] = []
        var selectedProviderID: String? = "zhipu"
        var selectedModel: String?
        var messageRenderers: [LumiMessageRendererItem] = []
        var revision = 0
        var agentTools: [any LumiAgentTool] = []
        var pendingMessages: [LumiPendingMessage] = []
        var routingMode: LumiModelRoutingMode = .manual
        var pendingToolConfirmation: LumiPendingToolConfirmation?

        func isSending(for conversationID: UUID?) -> Bool { false }
        @discardableResult func createConversation(title: String?) -> UUID { UUID() }
        @discardableResult func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
        func selectConversation(id: UUID) {}
        func deleteConversation(id: UUID) {}
        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
        @discardableResult func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
        func selectProvider(id: String, model: String?) {}
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
        func providerID(for conversationID: UUID?) -> String? { "zhipu" }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func setRoutingMode(_ mode: LumiModelRoutingMode) {}
        func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
        func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
        func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
        func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
        func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
        func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
        func registerToolService(_ toolService: (any LumiToolServicing)?) {}
        func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
        func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
        func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
        func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
        func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
        func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
        func enqueueText(_ text: String, in conversationID: UUID?) {}
        func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
        func continueTurn(in conversationID: UUID) {}
        func cancelSending(for conversationID: UUID?) {}
        func approvePendingTool() {}
        func rejectPendingTool() {}
        func removePendingMessage(id: UUID) {}
        func deleteMessage(id: UUID, in conversationID: UUID) {}
        func resendMessage(id: UUID, in conversationID: UUID) async {}
        func send(_ text: String, in conversationID: UUID?) async {}
        func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
            throw NSError(domain: "test", code: 1)
        }
        func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
            .init(currentTokens: 0, limit: 0)
        }
    }

    let hidden = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies()
    )
    let visible = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies {
            $0.register(LumiChatServicing.self, MockChatService())
        }
    )

    #expect(hidden.supportsChatSection)
    #expect(hidden.showsChatSection == false)
    #expect(visible.showsChatSection)
    #expect(visible.activeProviderID == "zhipu")
}

@Test func toolExecutionOnlyMessageDetection() {
    let conversationID = UUID()

    let substantiveReply = LumiChatMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "Here is the answer.",
        toolCalls: [LumiToolCall(id: "call-1", name: "read_file", arguments: "{}")]
    )
    #expect(!substantiveReply.isToolExecutionOnly)

    let toolSummary = LumiChatMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "正在执行 read_file",
        toolCalls: [LumiToolCall(id: "call-1", name: "read_file", arguments: "{}")]
    )
    #expect(toolSummary.isToolExecutionOnly)

    let emptyToolOnly = LumiChatMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        toolCalls: [LumiToolCall(id: "call-1", name: "read_file", arguments: "{}")]
    )
    #expect(emptyToolOnly.isToolExecutionOnly)

    let userMessage = LumiChatMessage(
        conversationID: conversationID,
        role: .user,
        content: "hello"
    )
    #expect(!userMessage.isToolExecutionOnly)
}
