import Foundation
import LanguageServerProtocol
import Testing
@testable import EditorKernelCore

struct EditorKernelCoreTests {
    @Test
    func cursorMotionWordAndLineBehaviorsRemainStable() {
        #expect(CursorMotionController.moveWordLeft(location: 10, text: "foo  +  bar").location == 8)
        #expect(CursorMotionController.moveWordRight(location: 0, text: "foo  +  bar").location == 3)
        #expect(CursorMotionController.smartHome(location: 9, text: "    value").location == 0)
        #expect(CursorMotionController.moveToEndOfLine(location: 0, text: "abc\r\ndef").location == 3)
    }

    @Test
    func cursorDeleteWordLeftReturnsExpectedRange() {
        let target = CursorMotionController.deleteWordLeft(location: 7, text: "foo bar")
        #expect(target.location == 4)
        #expect(target.selectionRange == NSRange(location: 4, length: 3))
    }

    @Test
    func snippetParserSeedsRepeatedPlaceholdersAndImplicitExit() {
        let repeated = EditorSnippetParser.parse("${1:name} = $1$0")
        #expect(repeated.text == "name = name")
        #expect(repeated.groups == [
            .init(index: 1, ranges: [
                NSRange(location: 0, length: 4),
                NSRange(location: 7, length: 4),
            ])
        ])
        #expect(repeated.exitSelection == NSRange(location: 11, length: 0))

        let implicit = EditorSnippetParser.parse("func ${1:name}(${2:value})")
        #expect(implicit.text == "func name(value)")
        #expect(implicit.groups.map(\.index) == [1, 2])
        #expect(implicit.exitSelection == NSRange(location: 16, length: 0))
    }

    @Test
    func multiCursorEditEngineInsertDeleteAndOutdentBehaviorsRemainStable() {
        let inserted = MultiCursorEditEngine.apply(
            text: "hello world",
            selections: [
                .init(location: 0, length: 5),
                .init(location: 6, length: 5),
            ],
            operation: .insert("x")
        )
        #expect(inserted.text == "x x")
        #expect(inserted.selections == [
            .init(location: 1, length: 0),
            .init(location: 7, length: 0),
        ])

        let deleted = MultiCursorEditEngine.apply(
            text: "abcd",
            selections: [
                .init(location: 1, length: 0),
                .init(location: 3, length: 1),
            ],
            operation: .deleteBackward
        )
        #expect(deleted.text == "bc")
        #expect(deleted.selections == [
            .init(location: 0, length: 0),
            .init(location: 3, length: 0),
        ])

        let outdented = MultiCursorEditEngine.apply(
            text: "    one\n    two",
            selections: [.init(location: 0, length: 13)],
            operation: .outdent(tabSize: 4, useSpaces: true)
        )
        #expect(outdented.text == "one\ntwo")
        #expect(outdented.selections == [.init(location: 0, length: 5)])
    }

    @Test
    func textEditApplierHandlesMultipleEditsAndRejectsInvalidRanges() {
        let edits = [
            TextEdit(
                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 5)),
                newText: "earth"
            ),
            TextEdit(
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
                newText: "hello"
            ),
        ]

        #expect(TextEditApplier.apply(edits: edits, to: "world\nworld") == "hello\nearth")

        let invalid = [
            TextEdit(
                range: LSPRange(start: Position(line: 3, character: 0), end: Position(line: 3, character: 1)),
                newText: "x"
            )
        ]
        #expect(TextEditApplier.apply(edits: invalid, to: "line") == nil)
    }
}
