import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

@MainActor
@Test func chatServiceCreatesAndPersistsConversation() async {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = ChatService(configuration: .coreDatabase(directory: directory))
    let id = service.createConversation(title: "Test")
    await service.send("Hello", in: id)

    let reloaded = ChatService(configuration: .coreDatabase(directory: directory))
    #expect(reloaded.conversations.count == 1)
    #expect(reloaded.messages(for: id).count == 2)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Lumi.db").path))
}

@MainActor
@Test func chatServicePersistsConversationPreferences() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = ChatService(configuration: .coreDatabase(directory: directory))
    let id = service.createConversation(title: "Verbose")
    service.setLanguage(.english, for: id)
    service.setAutomationLevel(.build, for: id)
    service.setVerbosity(.detailed, for: id)

    let reloaded = ChatService(configuration: .coreDatabase(directory: directory))
    #expect(reloaded.language(for: id) == .english)
    #expect(reloaded.automationLevel(for: id) == .build)
    #expect(reloaded.verbosity(for: id) == .detailed)
    #expect(reloaded.conversations.first(where: { $0.id == id })?.language == .english)
    #expect(reloaded.conversations.first(where: { $0.id == id })?.automationLevel == .build)
    #expect(reloaded.conversations.first(where: { $0.id == id })?.verbosity == .detailed)
}

@MainActor
@Test func loadEarlierMessagesExpandsVisibleWindowWithoutClearingConversation() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiChatKitPaginationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let service = ChatService(configuration: .coreDatabase(directory: directory))
    let coordinator = ChatSectionCoordinator(chatService: service)
    let conversationID = service.createConversation(title: "Paged")

    for index in 0..<15 {
        service.append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: "Message \(index)"
            )
        )
    }
    service.selectConversation(id: conversationID)

    let initial = coordinator.displayedMessages(for: conversationID)
    #expect(initial.count == 10)
    #expect(initial.first?.content == "Message 5")
    #expect(initial.last?.content == "Message 14")

    coordinator.loadEarlierMessages()

    let expanded = coordinator.displayedMessages(for: conversationID)
    #expect(expanded.count == 15)
    #expect(expanded.first?.content == "Message 0")
    #expect(expanded.last?.content == "Message 14")
    #expect(coordinator.selectedConversationID == conversationID)

    coordinator.loadEarlierMessages()
    #expect(coordinator.displayedMessages(for: conversationID).count == 15)
}
