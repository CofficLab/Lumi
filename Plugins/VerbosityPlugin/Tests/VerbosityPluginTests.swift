import Testing
import LumiCoreKit
@testable import VerbosityPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(VerbosityPlugin.policy == .alwaysOn)
    #expect(VerbosityPlugin.isConfigurable == false)
}

@MainActor
@Test func verbosityToolbarProvidesCustomView() async throws {
    let context = PluginContext(
        activeIcon: nil,
        isEditorVisible: false,
        showChat: .narrow,
        showsProjectToolbar: false,
        verbosityPreferenceContext: VerbosityPreferenceContext(
            currentVerbosity: .brief,
            selectedConversationId: nil,
            conversationVerbosityProvider: { nil },
            verbositySaver: { _ in }
        )
    )
    let missingCapabilityContext = PluginContext(activeIcon: nil, isEditorVisible: false, showChat: .narrow, showsProjectToolbar: false)

    let item = VerbosityPlugin.shared.addSidebarLeadingToolbarItems(context: context).first
    let view = VerbosityPlugin.shared.addSidebarToolbarItemView(itemId: "verbosity-toggle", context: context)
    let missingCapabilityView = VerbosityPlugin.shared.addSidebarToolbarItemView(itemId: "verbosity-toggle", context: missingCapabilityContext)
    let unknownView = VerbosityPlugin.shared.addSidebarToolbarItemView(itemId: "unknown", context: context)

    #expect(item?.id == "verbosity-toggle")
    #expect(view != nil)
    #expect(missingCapabilityView == nil)
    #expect(unknownView == nil)
}
