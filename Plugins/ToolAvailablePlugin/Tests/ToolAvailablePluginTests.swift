import Testing
import LumiCoreKit
@testable import ToolAvailablePlugin

@Test func packageLoads() async throws {
    #expect(ToolAvailablePlugin.policy == .optOut)
    #expect(ToolAvailablePlugin.shouldRegister == true)
    #expect(ToolAvailablePlugin.enabledByDefault == true)
}

@MainActor
@Test func contributesStatusBarViewForEditor() async throws {
    let editorContext = PluginContext(activeIcon: "chevron.left.forwardslash.chevron.right")
    let nonEditorContext = PluginContext(activeIcon: "bubble.left.and.bubble.right.fill")

    #expect(ToolAvailablePlugin.shared.addStatusBarTrailingView(context: editorContext) != nil)
    #expect(ToolAvailablePlugin.shared.addStatusBarTrailingView(context: nonEditorContext) == nil)
}
