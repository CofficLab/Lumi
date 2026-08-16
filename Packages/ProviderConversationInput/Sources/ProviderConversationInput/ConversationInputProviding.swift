import Foundation
import SwiftUI

@MainActor
public protocol ConversationInputProviding: ObservableObject {
    var text: String { get set }
    var inputHeight: CGFloat { get set }
    var isInputFocused: Bool { get set }
    var inputCursorPosition: Int { get set }
    var errorMessage: String? { get set }
    var isSending: Bool { get }
    func addToConversation(fileURLs: [URL])
    func clear()
}
