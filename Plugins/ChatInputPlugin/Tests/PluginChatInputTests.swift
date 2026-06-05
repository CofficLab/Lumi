import Foundation
import Testing
import LumiCoreKit
@testable import ChatInputPlugin

@MainActor
@Test func chatInputContributesFixedBottomSidebarSection() throws {
    let context = PluginContext(showChat: true)

    #expect(ChatInputPlugin.shared.addSidebarSections(context: context).isEmpty)
    #expect(ChatInputPlugin.shared.addSidebarBottomSections(context: context).count == 1)
    #expect(ChatInputPlugin.shared.addSidebarBottomSections(context: PluginContext()).isEmpty)
}

@MainActor
@Test func windowConversationVMSubmitsDraftText() async throws {
    var hostDraft = ""
    var submittedTexts: [String] = []
    let conversationId = UUID()
    let conversationVM = WindowConversationVM(
        selectedConversationId: conversationId,
        draftText: " hello ",
        draftTextSetter: { hostDraft = $0 },
        textSubmitter: { submittedTexts.append($0) }
    )

    #expect(conversationVM.canSubmitText)
    conversationVM.setDraftText(" hello ")
    await conversationVM.submitDraftText(conversationVM.draftText)

    #expect(submittedTexts == ["hello"])
    #expect(conversationVM.draftText.isEmpty)
    #expect(hostDraft.isEmpty)

    conversationVM.selectedConversationId = nil
    conversationVM.setDraftText("blocked")
    await conversationVM.submitDraftText(conversationVM.draftText)

    #expect(submittedTexts == ["hello"])
}

@MainActor
@Test func commandSuggestionsFilterSlashCommands() throws {
    #expect(CommandSuggestionView.suggestions(for: "").isEmpty)
    #expect(CommandSuggestionView.suggestions(for: "help").isEmpty)
    #expect(CommandSuggestionView.suggestions(for: "/c").map(\.command).contains("/clear"))
    #expect(CommandSuggestionView.suggestions(for: "/cmd").map(\.command) == ["/cmd"])
    #expect(CommandSuggestionView.suggestions(for: "/missing").isEmpty)
}

@MainActor
@Test func addToChatNotificationsRespectWindowIdWhenPresent() throws {
    let targetWindowId = UUID()
    let otherWindowId = UUID()

    let matching = Notification(
        name: Notification.Name("addToChat"),
        userInfo: ["text": "selected code", "windowId": targetWindowId]
    )
    #expect(InputView.addToChatText(from: matching, targetWindowId: targetWindowId) == "selected code")

    let otherWindow = Notification(
        name: Notification.Name("addToChat"),
        userInfo: ["text": "other code", "windowId": otherWindowId]
    )
    #expect(InputView.addToChatText(from: otherWindow, targetWindowId: targetWindowId) == nil)

    let broadcast = Notification(
        name: Notification.Name("addToChat"),
        userInfo: ["text": "legacy payload"]
    )
    #expect(InputView.addToChatText(from: broadcast, targetWindowId: targetWindowId) == "legacy payload")

    let empty = Notification(
        name: Notification.Name("addToChat"),
        userInfo: ["text": ""]
    )
    #expect(InputView.addToChatText(from: empty, targetWindowId: targetWindowId) == nil)
}
