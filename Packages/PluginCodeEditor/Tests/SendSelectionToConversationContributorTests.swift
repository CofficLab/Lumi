import Foundation
@testable import PluginCodeEditor
import ProviderEditor
import ProviderConversationInput
import Testing

@MainActor
struct SendSelectionToConversationContributorTests {
    @Test("reads a UTF-16 selection without breaking Unicode text")
    func selectedTextUsesUTF16Range() {
        let text = "前🙂后\nlet value = 1"
        let selected = "🙂后"
        let location = (text as NSString).range(of: selected).location

        #expect(SendSelectionToConversationContributor.selectedText(
            in: text,
            range: NSRange(location: location, length: (selected as NSString).length)
        ) == selected)
    }

    @Test("builds a code payload with relative file and line context")
    func messagePayloadIncludesContext() {
        let document = "func greet() {\n    print(\"hi\")\n}"
        let selected = "    print(\"hi\")"
        let selection = (document as NSString).range(of: selected)
        let payload = SendSelectionToConversationContributor.messagePayload(
            selectedText: selected,
            documentText: document,
            fileURL: URL(fileURLWithPath: "/tmp/project/Sources/Greet.swift"),
            projectRootPath: "/tmp/project",
            languageID: "swift",
            selection: selection
        )

        #expect(payload.contains("Sources/Greet.swift"))
        #expect(payload.contains("swift"))
        #expect(payload.contains(selected))
        #expect(payload.contains("\(CodeEditorLocalization.string("Line range")) 2"))
    }

    @Test("appends to the conversation input and focuses it")
    func appendPreservesExistingInput() {
        let input = DefaultConversationInputProvider()
        input.text = "先说这件事"

        SendSelectionToConversationContributor.append("选中的代码", to: input)

        #expect(input.text == "先说这件事\n\n选中的代码")
        #expect(input.isInputFocused)
    }

    @Test("contributes only when a conversation input provider is available")
    func contextMenuContributionRequiresConversationInput() {
        let context = EditorContextMenuContext(
            languageID: "swift",
            fileURL: nil,
            projectRootPath: nil,
            selectedText: "let",
            documentText: "let value = 1",
            selection: NSRange(location: 0, length: 3),
            isEditorActive: true,
            isLargeFileMode: false
        )

        let withoutInput = SendSelectionToConversationContributor(conversationInput: nil)
        #expect(withoutInput.provideItems(context: context).isEmpty)

        let input = DefaultConversationInputProvider()
        let withInput = SendSelectionToConversationContributor(conversationInput: input)
        #expect(withInput.provideItems(context: context).map(\.id) == [SendSelectionToConversationContributor.contributorID])
    }
}
