import Foundation
import LumiKernel
import Testing
@testable import MessageListPlugin

@MainActor
@Test func chatMessagesSectionPluginReturnsEmptyWhenChatSectionHidden() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .none
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
}

@MainActor
@Test func chatMessagesSectionPluginRequiresCoordinatorWhenVisible() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
}
