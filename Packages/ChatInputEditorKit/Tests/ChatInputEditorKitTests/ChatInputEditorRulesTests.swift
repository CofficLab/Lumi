import AppKit
import Testing
@testable import ChatInputEditorKit

@Suite("ChatInputEditorRules")
struct ChatInputEditorRulesTests {
    @Test("Swift character indices convert to UTF-16 offsets")
    func swiftToUTF16Index() {
        let text = "a🌳b"

        #expect(ChatInputEditorRules.swiftToUTF16Index(0, in: text) == 0)
        #expect(ChatInputEditorRules.swiftToUTF16Index(1, in: text) == 1)
        #expect(ChatInputEditorRules.swiftToUTF16Index(2, in: text) == 3)
        #expect(ChatInputEditorRules.swiftToUTF16Index(3, in: text) == 4)
    }

    @Test("UTF-16 offsets convert to Swift character indices")
    func utf16ToSwiftIndex() {
        let text = "a🌳b"

        #expect(ChatInputEditorRules.utf16ToSwiftIndex(0, in: text) == 0)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(1, in: text) == 1)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(2, in: text) == 3)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(3, in: text) == 2)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(4, in: text) == 3)
    }

    @Test("Index conversion clamps out-of-range input")
    func indexClamping() {
        let text = "abc"

        #expect(ChatInputEditorRules.swiftToUTF16Index(-10, in: text) == 0)
        #expect(ChatInputEditorRules.swiftToUTF16Index(10, in: text) == 3)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(-10, in: text) == 0)
        #expect(ChatInputEditorRules.utf16ToSwiftIndex(10, in: text) == 3)
    }

    @Test("Return key detection accepts main and keypad return")
    func returnKeyDetection() {
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 36, charactersIgnoringModifiers: nil))
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 76, charactersIgnoringModifiers: nil))
        #expect(ChatInputEditorRules.isReturnKey(keyCode: 0, charactersIgnoringModifiers: "\r"))
        #expect(!ChatInputEditorRules.isReturnKey(keyCode: 49, charactersIgnoringModifiers: " "))
    }

    @Test("Return handling ignores newline modifiers")
    func returnHandlingModifiers() {
        #expect(ChatInputEditorRules.shouldHandleReturnKey(
            keyCode: 36,
            charactersIgnoringModifiers: "\r",
            modifierFlags: []
        ))
        #expect(!ChatInputEditorRules.shouldHandleReturnKey(
            keyCode: 36,
            charactersIgnoringModifiers: "\r",
            modifierFlags: [.shift]
        ))
        #expect(!ChatInputEditorRules.shouldHandleReturnKey(
            keyCode: 36,
            charactersIgnoringModifiers: "\r",
            modifierFlags: [.option]
        ))
        #expect(!ChatInputEditorRules.shouldHandleReturnKey(
            keyCode: 36,
            charactersIgnoringModifiers: "\r",
            modifierFlags: [.command]
        ))
        #expect(!ChatInputEditorRules.shouldHandleReturnKey(
            keyCode: 36,
            charactersIgnoringModifiers: "\r",
            modifierFlags: [.control]
        ))
    }

    @Test("Enter command detection covers AppKit newline selectors")
    func enterCommandDetection() {
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertNewline(_:))))
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertLineBreak(_:))))
        #expect(ChatInputEditorRules.isEnterCommand(#selector(NSResponder.insertParagraphSeparator(_:))))
        #expect(!ChatInputEditorRules.isEnterCommand(#selector(NSResponder.moveUp(_:))))
    }

    @Test("Image file detection is case-insensitive")
    func imageFileDetection() {
        #expect(ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.PNG")))
        #expect(ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.heic")))
        #expect(!ChatInputEditorRules.isChatImageFileURL(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    @Test("Dropped path strings become file URLs only for absolute paths")
    func droppedPathStringConversion() {
        #expect(ChatInputEditorRules.fileURL(fromDroppedString: "/tmp/a.png")?.path == "/tmp/a.png")
        #expect(ChatInputEditorRules.fileURL(fromDroppedString: "relative/a.png") == nil)
        #expect(ChatInputEditorRules.fileURL(fromDroppedString: "") == nil)
    }
}
