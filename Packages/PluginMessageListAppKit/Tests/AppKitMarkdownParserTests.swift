import Foundation
import Testing
import MarkdownKitCore
@testable import MessageListAppKitPlugin

/// Layout cache tests run on the main actor (the cache is UI-side).
@MainActor
struct AppKitMarkdownParserTests {
    // MARK: - Block parsing (fixture-driven)

    @Test("markdown-showcase 解析出全部块类型")
    func parsesShowcaseBlocks() throws {
        let source = try FixtureLoader.markdownShowcase()
        let document = AppKitMarkdownParser.parse(source)

        #expect(document.isEmpty == false)

        // 标题
        let headings = document.blocks.compactMap { block -> (Int, String)? in
            guard case let .heading(level, text) = block else { return nil }
            return (level, text)
        }
        #expect(headings.contains { $0.0 == 1 && $0.1 == "Markdown Showcase" })
        #expect(headings.contains { $0.0 == 3 && $0.1 == "H3 heading" })

        // 段落（含 emoji-free 的强调文本）
        #expect(document.blocks.contains {
            if case let .paragraph(text) = $0 { return text.contains("italic text") }
            return false
        })

        // 列表
        #expect(document.blocks.contains {
            if case let .unorderedList(items) = $0 {
                return items.contains { $0.text == "first item" }
            }
            return false
        })
        #expect(document.blocks.contains {
            if case let .orderedList(items) = $0 {
                return items.contains { $0.text == "step one" && $0.index == 1 }
            }
            return false
        })

        // 任务列表
        let taskItems = document.blocks.compactMap { block -> [MarkdownListItem]? in
            guard case let .unorderedList(items) = block else { return nil }
            return items.allSatisfy { $0.taskState != nil } ? items : nil
        }
        #expect(taskItems.count == 1)
        #expect(taskItems.first?.contains { $0.taskState == .done && $0.text == "done item" } == true)

        // 引用
        #expect(document.blocks.contains {
            if case let .quote(text) = $0 { return text.contains("A short quote") }
            return false
        })

        // 分隔线
        #expect(document.blocks.contains { $0 == .thematicBreak })

        // 代码块（swift + text）
        let codeBlocks = document.blocks.compactMap { block -> (String?, String)? in
            guard case let .codeBlock(language, code) = block else { return nil }
            return (language, code)
        }
        #expect(codeBlocks.contains { $0.0 == "swift" && $0.1.contains("struct Greeting") })
        #expect(codeBlocks.contains { $0.0 == "text" })

        // Mermaid 识别
        let mermaid = codeBlocks.first { $0.0 == "mermaid" }
        #expect(mermaid != nil)
        #expect(MarkdownParser.isMermaidCodeBlock(language: mermaid?.0) == true)

        // 表格
        let tables = document.blocks.compactMap { block -> [String]? in
            guard case let .table(headers, _) = block else { return nil }
            return headers
        }
        #expect(tables.contains { $0 == ["Name", "Type", "Description"] })

        // CJK 长段落
        #expect(document.blocks.contains {
            if case let .paragraph(text) = $0 { return text.contains("这是一段很长的中文段落") }
            return false
        })
    }

    @Test("相同源码解析结果一致（确定性）")
    func deterministicParsing() throws {
        let source = try FixtureLoader.markdownShowcase()
        let a = AppKitMarkdownParser.parse(source)
        let b = AppKitMarkdownParser.parse(source)
        #expect(a == b)
        #expect(a.contentHash == b.contentHash)
    }

    // MARK: - Content hash

    @Test("FNV-1a hash 稳定且可区分")
    func hashStability() {
        let h1 = AppKitMarkdownParser.fnv1aHash("hello world")
        let h2 = AppKitMarkdownParser.fnv1aHash("hello world")
        let h3 = AppKitMarkdownParser.fnv1aHash("hello worlD")
        #expect(h1 == h2)
        #expect(h1 != h3)
        #expect(h1.count == 16) // 8 字节 hex
    }

    // MARK: - Inline formatting

    @Test("内联加粗解析")
    func inlineBold() {
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: "a **bold** tail")
        let bold = runs.first { $0.kind == .bold }
        #expect(bold != nil)
        #expect((runs[0].kind == .plain))
        // "**" 从 index 2 开始，内容 "bold" 从 index 4 起、长 4。
        #expect(bold?.range == NSRange(location: 4, length: 4))
    }

    @Test("内联斜体解析")
    func inlineItalic() {
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: "text *it* end")
        // "*" 在 index 5，内容 "it" 在 6..8。
        #expect(runs.contains { $0.kind == .italic && $0.range == NSRange(location: 6, length: 2) })
    }

    @Test("内联代码解析")
    func inlineCode() {
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: "use `let x = 1` now")
        let code = runs.first { $0.kind == .code }
        #expect(code != nil)
        #expect((runs[0].kind == .plain))
    }

    @Test("内联链接解析")
    func inlineLink() {
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: "see [example](https://example.com) docs")
        let link = runs.first { if case .link(_) = $0.kind { return true }; return false }
        #expect(link != nil)
        guard case let .link(url) = link?.kind else {
            Issue.record("link kind mismatch")
            return
        }
        #expect(url == "https://example.com")
        // "see " 4 字符，label "example" 从 index 5 起、长 7。
        #expect(link?.range == NSRange(location: 5, length: 7))
    }

    @Test("混合内联标记依次解析")
    func mixedInline() {
        let text = "**bold** and `code` and [link](https://x.io)"
        let runs = AppKitInlineMarkdownFormatter.parseRuns(in: text)
        let kinds = runs.map(\.kind)
        #expect(kinds.contains(.bold))
        #expect(kinds.contains(.code))
        #expect(kinds.contains { if case .link(_) = $0 { return true }; return false })
    }

    // MARK: - Layout cache

    @Test("文档缓存：二次访问命中")
    func documentCacheHits() {
        let cache = AppKitMessageLayoutCache()
        let source = "# Hi\n\nSome **text** here."
        _ = cache.document(for: source)
        #expect(cache.documentMisses == 1)

        _ = cache.document(for: source)
        #expect(cache.documentMisses == 1)
        #expect(cache.documentHits == 1)

        _ = cache.document(for: source + " changed")
        #expect(cache.documentMisses == 2)
    }

    @Test("高度缓存：同内容同 key 命中，不同 key 独立")
    func heightCache() {
        let cache = AppKitMessageLayoutCache()
        let key = AppKitRowLayoutKey(
            rowID: "r1", contentHash: "abc", availableWidth: 600,
            scale: 2, themeRevision: 1, verbosity: "v2"
        )
        #expect(cache.height(for: key, fallback: { 120 }) == 120)
        #expect(cache.heightMisses == 1)

        #expect(cache.height(for: key, fallback: { 999 }) == 120)
        #expect(cache.heightHits == 1)

        let different = AppKitRowLayoutKey(
            rowID: "r1", contentHash: "abc", availableWidth: 500,
            scale: 2, themeRevision: 1, verbosity: "v2"
        )
        #expect(cache.height(for: different, fallback: { 200 }) == 200)
        #expect(cache.heightMisses == 2)
    }

    @Test("按行失效与按主题失效")
    func invalidation() {
        let cache = AppKitMessageLayoutCache()
        let key = AppKitRowLayoutKey(
            rowID: "r1", contentHash: "abc", availableWidth: 600,
            scale: 2, themeRevision: 1, verbosity: "v2"
        )
        _ = cache.height(for: key, fallback: { 120 })

        cache.invalidate(rowID: "r1")
        #expect(cache.cachedHeight(for: key) == nil)

        _ = cache.height(for: key, fallback: { 140 })
        cache.invalidate(themeRevision: 1)
        #expect(cache.cachedHeight(for: key) == nil)

        _ = cache.height(for: key, fallback: { 160 })
        cache.invalidateAll()
        #expect(cache.cachedHeight(for: key) == nil)
        #expect(cache.documentMisses == 0) // invalidateAll 也清空文档
    }

    @Test("LRU 上限生效")
    func lruEviction() {
        let cache = AppKitMessageLayoutCache(documentLimit: 2, heightLimit: 3)
        _ = cache.document(for: "one")
        _ = cache.document(for: "two")
        _ = cache.document(for: "three")
        #expect(cache.cachedDocument(for: "one") == nil) // 最旧被逐出
        #expect(cache.cachedDocument(for: "two") != nil)
        #expect(cache.cachedDocument(for: "three") != nil)

        for i in 0..<4 {
            _ = cache.height(
                for: AppKitRowLayoutKey(
                    rowID: "r\(i)", contentHash: "h\(i)", availableWidth: 600,
                    scale: 1, themeRevision: 0, verbosity: "v2"
                ),
                fallback: { 50 }
            )
        }
        #expect(cache.cachedHeight(
            for: AppKitRowLayoutKey(
                rowID: "r0", contentHash: "h0", availableWidth: 600,
                scale: 1, themeRevision: 0, verbosity: "v2"
            )
        ) == nil)
    }
}
