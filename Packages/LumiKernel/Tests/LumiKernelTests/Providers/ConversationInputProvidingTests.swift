import Foundation
import Testing
@testable import LumiKernel

/// `ConversationInputProviding` 的内核契约测试。
///
/// 模块对应:`Sources/LumiKernel/Providers/ConversationInputProviding.swift`。
/// 验证服务注册/解析 + 通过 kernel 透传状态。
@Suite("ConversationInputProviding")
@MainActor
struct ConversationInputProvidingTests {
    @Test("注册后可通过 kernel.conversationInput 解析,且为同一实例")
    func registerAndResolve() throws {
        let kernel = KernelTestKit.makeKernel()
        let input = MockConversationInputProviding()

        try kernel.registerConversationInputService(input)

        let resolved = kernel.conversationInput
        #expect(resolved != nil)
        #expect(resolved as? MockConversationInputProviding === input)
    }

    @Test("通过 kernel 透传的状态与底层实例同步")
    func stateSharedThroughKernel() throws {
        let kernel = KernelTestKit.makeKernel()
        let input = MockConversationInputProviding()
        try kernel.registerConversationInputService(input)

        kernel.conversationInput?.text = "hello kernel"
        kernel.conversationInput?.inputHeight = 120
        kernel.conversationInput?.isInputFocused = true
        kernel.conversationInput?.inputCursorPosition = 3
        kernel.conversationInput?.errorMessage = "boom"

        #expect(input.text == "hello kernel")
        #expect(input.inputHeight == 120)
        #expect(input.isInputFocused == true)
        #expect(input.inputCursorPosition == 3)
        #expect(input.errorMessage == "boom")
    }

    @Test("可接受要加入会话的文件引用")
    func acceptFileReferences() throws {
        let kernel = KernelTestKit.makeKernel()
        let input = MockConversationInputProviding()
        try kernel.registerConversationInputService(input)

        let fileA = URL(fileURLWithPath: "/tmp/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/B.swift")

        kernel.conversationInput?.addToConversation(fileURLs: [fileA, fileB], windowId: nil)

        #expect(input.text == """
        Files to add to conversation:
        - /tmp/A.swift
        - /tmp/B.swift
        """)
        #expect(input.isInputFocused == true)
    }
}
