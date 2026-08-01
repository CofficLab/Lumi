import Foundation
import LumiKernel
import Testing
@testable import ConversationTitlePlugin

@MainActor
@Test func packageLoads() async throws {
    let plugin = ConversationTitlePlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-title")
}

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    let plugin = ConversationTitlePlugin()
    #expect(plugin.policy == .alwaysOn)
    #expect(plugin.policy.isConfigurable == false)
}

@MainActor
@Test func pluginDoesNotInjectTitleHintMiddleware() {
    let middlewares = ConversationTitlePlugin.sendMiddlewares(lumiCore: ())

    #expect(middlewares.isEmpty)
}

@MainActor
@Test func pluginRegistersTitleTool() {
    let tools = ConversationTitlePlugin.agentTools(lumiCore: ())

    #expect(tools.map(\.name).contains("update_conversation_title"))
}

@Test func autoTitleNormalizerKeepsFirstCleanLine() {
    let title = AutoConversationTitleService.normalizeTitle("""
    "修复 SwiftData 分页"

    说明：这是标题
    """)

    #expect(title == "修复 SwiftData 分页")
}

@Test func autoTitleNormalizerCapsLongTitles() {
    let title = AutoConversationTitleService.normalizeTitle(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    )

    #expect(title == "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN")
}

@Test func autoTitlePlaceholderCollapsesAndTruncatesFirstMessage() {
    let title = AutoConversationTitleService.placeholderTitle(
        forFirstUserMessage: "  abcdefghij\nklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ  "
    )

    #expect(title == "abcdefghij klmnopqrstuvwxyzABCDEFGHIJKLM…")
}

@Test func autoTitleSkipsWhenGeneratedTitleMatchesCurrentTitle() {
    let shouldApply = AutoConversationTitleService.shouldApplyGeneratedTitle(
        currentTitle: "修复 SwiftData 分页",
        hasCustomTitle: true,
        firstUserMessageContent: "修复 SwiftData 分页",
        generatedTitle: "修复 SwiftData 分页"
    )

    #expect(!shouldApply)
}
