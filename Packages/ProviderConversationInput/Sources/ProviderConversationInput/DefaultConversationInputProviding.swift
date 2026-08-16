import Foundation

@MainActor
public final class DefaultConversationInputProviding: ConversationInputProviding {
    @Published public var text = ""
    @Published public var inputHeight: CGFloat = 40
    @Published public var isInputFocused = false
    @Published public var inputCursorPosition = 0
    @Published public var errorMessage: String?
    @Published public private(set) var isSending = false
    public init() {}
    public func addToConversation(fileURLs: [URL]) { text += fileURLs.map(\.path).joined(separator: "\n") }
    public func clear() { text = ""; errorMessage = nil }
}
