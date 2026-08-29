import EditorService
import Foundation
@testable import PluginCodeEditor
import ProviderConversationInput
import Testing

@MainActor
struct SendSelectionToConversationContributorTests {
    @Test("reads a UTF-16 selection without breaking Unicode text")
    func selectedTextUsesTextViewRange() {
        let text = "前🙂后\nlet value = 1"
        let textView = TextView(string: text)
        let selected = "🙂后"
        let location = (text as NSString).range(of: selected).location
        textView.selectionManager.setSelectedRange(
            NSRange(location: location, length: (selected as NSString).length)
        )

        #expect(SendSelectionToConversationContributor.selectedText(in: textView) == selected)
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
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let textView = TextView(string: "let value = 1")
        textView.selectionManager.setSelectedRange(NSRange(location: 0, length: 3))
        let context = EditorCommandContext(
            languageId: "swift",
            hasSelection: true,
            line: 1,
            character: 1
        )

        let withoutInput = SendSelectionToConversationContributor(conversationInput: nil)
        #expect(withoutInput.provideContextMenuItems(
            context: context,
            state: editor.state,
            textView: textView
        ).isEmpty)

        let input = DefaultConversationInputProvider()
        let withInput = SendSelectionToConversationContributor(conversationInput: input)
        #expect(withInput.provideContextMenuItems(
            context: context,
            state: editor.state,
            textView: textView
        ).map(\.id) == [SendSelectionToConversationContributor.contributorID])
    }
}
