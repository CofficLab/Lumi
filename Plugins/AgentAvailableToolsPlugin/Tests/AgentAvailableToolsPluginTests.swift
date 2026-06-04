import Testing
import LumiCoreKit
@testable import AgentAvailableToolsPlugin

@Test func packageLoads() async throws {
    #expect(AgentAvailableToolsPlugin.policy == .optOut)
    #expect(AgentAvailableToolsPlugin.shouldRegister == true)
    #expect(AgentAvailableToolsPlugin.enabledByDefault == true)
}

@MainActor
@Test func contributesStatusBarViewForEditor() async throws {
    let editorContext = PluginContext(activeIcon: "chevron.left.forwardslash.chevron.right")
    let nonEditorContext = PluginContext(activeIcon: "bubble.left.and.bubble.right.fill")

    #expect(AgentAvailableToolsPlugin.shared.addStatusBarTrailingView(context: editorContext) != nil)
    #expect(AgentAvailableToolsPlugin.shared.addStatusBarTrailingView(context: nonEditorContext) == nil)
}
