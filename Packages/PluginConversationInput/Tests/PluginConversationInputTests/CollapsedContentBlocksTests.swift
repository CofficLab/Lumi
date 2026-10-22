import AppKit
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 折叠块区间的计算与上报。
///
/// 这是「粘贴时是折叠块、发出后却展开成一大段」这条链路的起点：
/// 编辑器必须把 chip 在拍平正文中的位置算出来并上报，否则发送端拿不到区间。
@MainActor
@Suite("CollapsedContentBlocks")
struct CollapsedContentBlocksTests {
    @Test("chip 拍平后保留原文，区间指向该段在正文中的位置")
    func flattensChipIntoTextWithRange() {
        let pasted = "PASTED-BODY"
        let storage = NSTextStorage(string: "before ")
        let attachment = PastePreviewAttachment(originalText: pasted)
        storage.append(NSAttributedString(attachment: attachment))
        storage.append(NSAttributedString(string: " after"))

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(result.hasAttachments)
        #expect(result.text == "before \(pasted) after")
        #expect(result.blocks.count == 1)

        let block = try! #require(result.blocks.first)
        #expect(block.start == "before ".count)
        #expect(block.length == pasted.count)
        #expect(block.title == attachment.chipTitle)
        #expect(block.systemImage == attachment.systemImage)

        // 区间必须真的指向那段文字。
        let start = result.text.index(result.text.startIndex, offsetBy: block.start)
        let end = result.text.index(start, offsetBy: block.length)
        #expect(String(result.text[start..<end]) == pasted)
    }

    @Test("多个 chip 的区间各自指向自己那一段")
    func tracksMultipleChips() {
        let storage = NSTextStorage()
        storage.append(NSAttributedString(string: "a"))
        storage.append(NSAttributedString(attachment: PastePreviewAttachment(originalText: "ONE")))
        storage.append(NSAttributedString(string: "b"))
        storage.append(NSAttributedString(attachment: PastePreviewAttachment(originalText: "TWO")))
        storage.append(NSAttributedString(string: "c"))

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(result.text == "aONEbTWOc")
        #expect(result.blocks.count == 2)
        #expect(result.blocks.map(\.start) == [1, 5])
        #expect(result.blocks.map(\.length) == [3, 3])
    }

    @Test("没有 chip 时不产生区间")
    func producesNoBlocksForPlainText() {
        let storage = NSTextStorage(string: "plain text")

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(!result.hasAttachments)
        #expect(result.blocks.isEmpty)
        #expect(result.text == "plain text")
    }

    @Test("编辑器把折叠块区间上报给上层")
    func reportsCollapsedBlocksUpward() {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false
        var reported: [CollapsedContentBlock] = []

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            onCollapsedBlocksChanged: { reported = $0 },
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = EditorTextView()
        coordinator.attach(to: textView)

        textView.hasPastePreviewAttachments = true
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: "BODY"))
        )

        coordinator.publishCommittedTextForTesting(from: textView)

        #expect(draft == "BODY")
        #expect(reported.count == 1)
        #expect(reported.first?.start == 0)
        #expect(reported.first?.length == 4)
    }
}
