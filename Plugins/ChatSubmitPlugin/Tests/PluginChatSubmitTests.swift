import Testing
@testable import ChatSubmitPlugin
import LumiCoreKit

@Test func metadataIsStable() throws {
    #expect(ChatSubmitPlugin.id == "ChatSubmit")
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ChatSubmitPlugin.policy == .alwaysOn)
    #expect(ChatSubmitPlugin.isConfigurable == false)
}

@MainActor
@Test func chatSubmitToolbarProvidesClickableCustomView() async throws {
    let submitContext = ChatSubmitContext(
        canSubmitProvider: { true },
        draftTextProvider: { "hello" },
        submitter: { _ in }
    )
    let context = PluginContext(
        activeIcon: nil,
        isEditorVisible: false,
        showChat: .narrow,
        showsProjectToolbar: false,
        chatSubmitContext: submitContext
    )
    let missingCapabilityContext = PluginContext(activeIcon: nil, isEditorVisible: false, showChat: .narrow, showsProjectToolbar: false)

    let item = ChatSubmitPlugin.shared.addSidebarTrailingToolbarItems(context: context).first
    let view = ChatSubmitPlugin.shared.addSidebarToolbarItemView(itemId: "chat-submit", context: context)
    let missingCapabilityView = ChatSubmitPlugin.shared.addSidebarToolbarItemView(itemId: "chat-submit", context: missingCapabilityContext)
    let unknownView = ChatSubmitPlugin.shared.addSidebarToolbarItemView(itemId: "unknown", context: context)

    #expect(item?.id == "chat-submit")
    #expect(view != nil)
    #expect(missingCapabilityView == nil)
    #expect(unknownView == nil)
}
