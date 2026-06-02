import Foundation

/// 窗口级聊天草稿状态。
///
/// 输入框插件和右侧栏拖放插件通过此 VM 交换草稿文本状态，避免插件之间直接持有引用。
@MainActor
final class WindowChatDraftVM: ObservableObject {
    @Published var text: String = ""
    @Published var cursorPosition: Int = 0

    func clear() {
        text = ""
        cursorPosition = 0
    }

    func append(_ newText: String) {
        let trimmedNewText = newText.trimmingCharacters(in: .whitespaces)

        let needsLeadingSpace = !text.isEmpty && !text.hasSuffix(" ")
        let needsTrailingSpace = !trimmedNewText.hasSuffix(" ")

        var finalText = trimmedNewText
        if needsLeadingSpace {
            finalText = " " + finalText
        }
        if needsTrailingSpace {
            finalText += " "
        }

        text += finalText
        cursorPosition = text.count
    }

    func set(_ newText: String) {
        text = newText
        cursorPosition = newText.count
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
