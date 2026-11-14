import AppKit
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 编辑器拍平缓存（见 issue #1261）。
///
/// 带 chip 时，每次按键都会让 `publishCommittedText` 与随后的 `updateNSView`
/// 各拍平整篇文档一遍。修复按文本存储版本缓存拍平结果：版本未变即复用，
/// 只有真正改动存储才重算。
///
/// 缓存最大的风险是**发 stale**——撤销、外部代码直接改 `textStorage` 都不走
/// `didChangeText`，若版本号漏掉这些路径，就会把已删除的 chip 或 U+FFFC
/// 占位符当正文发出去。因此本套件重点锁定「版本号覆盖全部改动路径」与
/// 「改动后缓存立即失效」。
@MainActor
@Suite("编辑器拍平缓存")
struct EditorFlattenCacheTests {

    @Test("直接改 textStorage 也递增版本号（append / delete / setAttributedString）")
    func storageMutationBumpsRevision() {
        let fixture = EditorFixture()
        let start = fixture.textView.storageRevision

        fixture.textView.textStorage?.append(NSAttributedString(string: "a"))
        let afterAppend = fixture.textView.storageRevision
        #expect(afterAppend > start)

        fixture.textView.textStorage?.deleteCharacters(in: NSRange(location: 0, length: 1))
        let afterDelete = fixture.textView.storageRevision
        #expect(afterDelete > afterAppend)

        fixture.textView.textStorage?.setAttributedString(NSAttributedString(string: "b"))
        #expect(fixture.textView.storageRevision > afterDelete)
    }

    @Test("无存储改动时重复发布复用缓存，版本号不变")
    func repeatedPublishReusesCacheWithoutMutation() throws {
        let fixture = EditorFixture()
        fixture.textView.hasPastePreviewAttachments = true
        fixture.textView.textStorage?.append(NSAttributedString(string: "summarize "))
        fixture.textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: "BODY"))
        )

        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)
        #expect(fixture.draft == "summarize BODY")

        let revisionAfterFirst = fixture.textView.storageRevision
        let cached = try #require(fixture.textView.cachedResolvedContent())
        #expect(cached.text == "summarize BODY")
        #expect(cached.blocks.count == 1)

        // 再次发布且无任何存储改动：版本不变，命中同一份缓存。
        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)
        #expect(fixture.textView.storageRevision == revisionAfterFirst)
        #expect(fixture.draft == "summarize BODY")
        #expect(fixture.textView.cachedResolvedContent()?.text == "summarize BODY")
    }

    @Test("直接追加文字后发布得到新正文，缓存不发 stale")
    func directStorageEditInvalidatesCache() throws {
        let fixture = EditorFixture()
        fixture.textView.hasPastePreviewAttachments = true
        fixture.textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: "BODY"))
        )
        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)
        #expect(fixture.draft == "BODY")
        #expect(fixture.textView.cachedResolvedContent() != nil)

        // 直接在 chip 后追加文字（模拟外部/撤销路径，不走 didChangeText）。
        fixture.textView.textStorage?.append(NSAttributedString(string: " tail"))
        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)

        #expect(fixture.draft == "BODY tail")
        let block = try #require(fixture.reported.first)
        #expect(block.start == 0)
        #expect(block.length == 4)
    }

    @Test("删除 chip 后缓存失效，正文不再含 chip 原文")
    func deletingChipInvalidatesCache() {
        let fixture = EditorFixture()
        fixture.textView.textStorage?.append(NSAttributedString(string: "A "))
        fixture.textView.hasPastePreviewAttachments = true
        fixture.textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: "BODY"))
        )
        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)
        #expect(fixture.draft == "A BODY")

        fixture.textView.textStorage?.deleteCharacters(in: NSRange(location: 2, length: 1))
        fixture.coordinator.publishCommittedTextForTesting(from: fixture.textView)

        #expect(fixture.draft == "A ")
        #expect(fixture.reported.isEmpty)
        #expect(!fixture.textView.hasPastePreviewAttachments)
    }
}

// MARK: - Fixture

/// 搭建与真实编辑路径一致的 view + coordinator + EditorTextView。
///
/// binding 用 `[unowned self]` 捕获 fixture：测试期间 fixture 始终存活，
/// 草稿与上报的折叠块都写回 fixture 的可变属性，便于断言。
@MainActor
private final class EditorFixture {
    var draft = ""
    var height = ChatInputEditorView.minHeight
    var focused = false
    var cursor = 0
    var dragging = false
    var reported: [CollapsedContentBlock] = []
    let textView = EditorTextView()
    var coordinator: ChatInputEditorView.Coordinator!

    init() {
        let view = ChatInputEditorView(
            text: Binding(get: { [unowned self] in draft }, set: { [unowned self] in draft = $0 }),
            height: Binding(get: { [unowned self] in height }, set: { [unowned self] in height = $0 }),
            onSubmit: {},
            onCollapsedBlocksChanged: { [unowned self] in reported = $0 },
            isFocused: Binding(get: { [unowned self] in focused }, set: { [unowned self] in focused = $0 }),
            cursorPosition: Binding(get: { [unowned self] in cursor }, set: { [unowned self] in cursor = $0 }),
            isImageDragHovering: Binding(get: { [unowned self] in dragging }, set: { [unowned self] in dragging = $0 })
        )
        coordinator = view.makeCoordinator()
        coordinator.attach(to: textView)
    }
}