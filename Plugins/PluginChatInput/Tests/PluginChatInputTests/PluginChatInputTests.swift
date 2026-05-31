import Foundation
import Testing
import LumiCoreKit
@testable import PluginChatInput

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
