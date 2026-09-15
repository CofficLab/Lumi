import Foundation
import Testing
@testable import ProviderConversationInput

@Test @MainActor func providerStartsWithTheInputEditorsMinimumHeight() {
    let provider = DefaultConversationInputProvider()

    #expect(provider.text.isEmpty)
    #expect(provider.inputHeight == 64)
    #expect(!provider.isInputFocused)
    #expect(provider.inputCursorPosition == 0)
    #expect(provider.errorMessage == nil)
    #expect(!provider.isSending)
}

@Test @MainActor func textObserversReceiveOnlyDistinctChangesAndCanBeCancelled() {
    let provider = DefaultConversationInputProvider()
    var received: [String] = []
    let handle = provider.addTextObserver { received.append($0) }

    provider.text = "first"
    provider.text = "first"
    provider.text = "second"
    #expect(received == ["first", "second"])

    handle.cancel()
    handle.cancel()
    provider.text = "after cancel"
    #expect(received == ["first", "second"])
}

@Test @MainActor func errorObserversReceiveDistinctMessagesAndClear() {
    let provider = DefaultConversationInputProvider()
    var receivedMessages: [String] = []
    var clearEvents = 0
    let handle = provider.addObserver { event in
        guard case .errorMessageChanged(let message) = event else { return }
        if let message {
            receivedMessages.append(message)
        } else {
            clearEvents += 1
        }
    }

    provider.errorMessage = "Unable to send"
    provider.errorMessage = "Unable to send"
    provider.clear()
    provider.clear()

    #expect(receivedMessages == ["Unable to send"])
    #expect(clearEvents == 1)
    handle.cancel()
    handle.cancel()
    provider.errorMessage = "ignored"
    #expect(receivedMessages == ["Unable to send"])
}

@Test @MainActor func filePathsAppendAsSeparateLinesWithoutAnExtraBlankLine() {
    let provider = DefaultConversationInputProvider()
    let first = URL(fileURLWithPath: "/tmp/first.swift")
    let second = URL(fileURLWithPath: "/tmp/second.swift")

    provider.addToConversation(fileURLs: [first, second])
    #expect(provider.text == "/tmp/first.swift\n/tmp/second.swift")

    provider.text = "Review these files"
    provider.addToConversation(fileURLs: [first])
    #expect(provider.text == "Review these files\n/tmp/first.swift")

    provider.text = "Prompt already ends with newline\n"
    provider.addToConversation(fileURLs: [second])
    #expect(provider.text == "Prompt already ends with newline\n/tmp/second.swift")

    let existingText = provider.text
    provider.addToConversation(fileURLs: [])
    #expect(provider.text == existingText)
}
