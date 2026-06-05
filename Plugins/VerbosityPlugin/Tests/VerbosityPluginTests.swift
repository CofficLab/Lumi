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
    let context = PluginContext(activeIcon: nil, isEditorVisible: false, showChat: true, showsProjectToolbar: false)

    let item = VerbosityPlugin.shared.addSidebarLeadingToolbarItems(context: context).first
    let view = VerbosityPlugin.shared.addSidebarToolbarItemView(itemId: "verbosity-toggle", context: context)
    let unknownView = VerbosityPlugin.shared.addSidebarToolbarItemView(itemId: "unknown", context: context)

    #expect(item?.id == "verbosity-toggle")
    #expect(view != nil)
    #expect(unknownView == nil)
}
