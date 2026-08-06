import Testing
import LumiKernel
@testable import ConversationVerbosityPlugin

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationVerbosityPlugin().policy == .alwaysOn)
}

@MainActor
@Test func responseStylePromptCoversAllLevels() {
    let v1 = VerbosityWillSendToLLMHook.responseStylePrompt(for: .brief)
    let v2 = VerbosityWillSendToLLMHook.responseStylePrompt(for: .standard)
    let v3 = VerbosityWillSendToLLMHook.responseStylePrompt(for: .detailed)

    #expect(v1.contains("V1"))
    #expect(v1.contains("concise"))
    #expect(v2.contains("V2"))
    #expect(v3.contains("V3"))
    #expect(v3.contains("thorough"))
}
