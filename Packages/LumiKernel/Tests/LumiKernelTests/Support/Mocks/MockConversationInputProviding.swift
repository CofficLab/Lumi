import Foundation
import SwiftUI
@testable import LumiKernel

/// 测试用 `ConversationInputProviding` 实现,记录 send/stop 调用次数。
@MainActor
final class MockConversationInputProviding: ConversationInputProviding {
    @Published var text: String = ""
    @Published var inputHeight: CGFloat = 64
    @Published var isInputFocused: Bool = false
    @Published var inputCursorPosition: Int = 0
    @Published var errorMessage: String?

    var isSendingValue: Bool = false
    var canSendValue: Bool = true
    private(set) var stopCallCount: Int = 0
    private(set) var sendCallCount: Int = 0

    func isSending(kernel: LumiKernel) -> Bool {
        isSendingValue
    }

    func canSend(kernel: LumiKernel) -> Bool {
        canSendValue
    }

    func send(kernel: LumiKernel) {
        sendCallCount += 1
    }

    func stop(kernel: LumiKernel) {
        stopCallCount += 1
    }

    func addToConversation(fileURLs: [URL], windowId: UUID?) {
        let paths = fileURLs.map { $0.standardizedFileURL.path }
        guard !paths.isEmpty else { return }

        let referenceBlock = (["Files to add to conversation:"] + paths.map { "- \($0)" })
            .joined(separator: "\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = referenceBlock
        } else {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + referenceBlock
        }
        isInputFocused = true
    }
}
