import Testing
import LumiKernel
@testable import ChatModePlugin

@MainActor
@Test func appLLMVMPropagatesA1A2A3ChatModes() async throws {
    var propagated: [ChatMode] = []
    let llmVM = AppLLMVM(chatModeSetter: { propagated.append($0) })

    llmVM.setChatMode(.chat)
    llmVM.setChatMode(.autonomous)

    #expect(propagated == [.chat, .autonomous])
    #expect(llmVM.chatMode == .autonomous)
    #expect(ChatMode(rawValue: "a1") == .chat)
    #expect(ChatMode(rawValue: "a2") == .build)
    #expect(ChatMode(rawValue: "a3") == .autonomous)
    #expect(ChatMode(rawValue: "ask") == .chat)
}
