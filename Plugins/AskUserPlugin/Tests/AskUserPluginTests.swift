import Foundation
import LumiKernel
import Testing
@testable import AskUserPlugin

// MARK: - Plugin Info Tests

@Suite @MainActor struct AskUserPluginInfoTests {

    @Test func pluginId() {
        #expect(AskUserPlugin().id == "plugin-ask-user")
    }

    @Test func pluginNameIsNotEmpty() {
        #expect(!AskUserPlugin().name.isEmpty)
    }

    @Test func pluginOrder() {
        #expect(AskUserPlugin().order == 100)
    }
}

// MARK: - Plugin Properties Tests

@Suite @MainActor struct AskUserPluginPropertiesTests {

    @Test func pluginPolicyIsAlwaysOn() {
        // 始终启用，不可禁用（通过 LumiFactory 注册后立即可用）
        #expect(AskUserPlugin().policy == .alwaysOn)
    }
}
