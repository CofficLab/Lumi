import AppKit
import Testing
import SwiftUI
@testable import MarkdownKit
@testable import MarkdownKitCore

@MainActor
struct MarkdownQuoteLayoutTests {

    // MARK: - 解析层：quote 的 text 是否有多余空行

    @Test
    func parsedQuoteTextHasNoSurroundingNewlines() {
        let blocks = MarkdownParser.parse("> 引用内容")

        guard blocks.count == 1, case let .quote(text) = blocks[0] else {
            Issue.record("Expected exactly one quote block")
            return
        }

        #expect(!text.hasPrefix("\n"))
        #expect(!text.hasSuffix("\n"))
        #expect(!text.contains("\n\n"))
    }

    @Test
    func parsedMultiLineQuoteTextHasNoExtraBlankLines() {
        let blocks = MarkdownParser.parse("> 第一行\n> 第二行\n> 第三行")

        guard blocks.count == 1, case let .quote(text) = blocks[0] else {
            Issue.record("Expected exactly one quote block")
            return
        }

        #expect(!text.hasPrefix("\n"))
        #expect(!text.hasSuffix("\n"))
        #expect(!text.contains("\n\n"))
    }

    @Test
    func parsedQuoteFollowedByParagraphProducesTwoBlocks() {
        let blocks = MarkdownParser.parse("> 引用内容\n\n后续段落")

        #expect(blocks.count == 2)
        if case let .quote(text) = blocks[0] {
            #expect(text == "引用内容")
        } else {
            Issue.record("First block should be quote")
        }
        if case let .paragraph(text) = blocks[1] {
            #expect(text == "后续段落")
        } else {
            Issue.record("Second block should be paragraph")
        }
    }

    // MARK: - 尺寸对比：quote vs paragraph

    @Test
    func quoteBlockIsNotTallerThanEquivalentParagraph() async throws {
        let quoteSize = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容").frame(width: 300)
        )
        let paragraphSize = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "引用内容").frame(width: 300)
        )

        let heightDiff = quoteSize.height - paragraphSize.height
        print("quote: \(quoteSize.height), paragraph: \(paragraphSize.height), diff: \(heightDiff)")
        #expect(heightDiff < 20)
    }

    @Test
    func quoteInBubbleIsNotTallerThanEquivalentParagraph() async throws {
        let quoteSize = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容")
                .padding(10).padding(.trailing, 20)
                .frame(width: 300, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        let paragraphSize = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "引用内容")
                .padding(10).padding(.trailing, 20)
                .frame(width: 300, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )

        let heightDiff = quoteSize.height - paragraphSize.height
        print("bubble quote: \(quoteSize.height), bubble paragraph: \(paragraphSize.height), diff: \(heightDiff)")
        #expect(heightDiff < 20)
    }

    @Test
    func quoteInListIsNotTallerThanEquivalentParagraph() async throws {
        let quoteSize = try await fittingSize(
            for: List {
                MarkdownBlockRenderer(markdown: "> 引用内容")
                    .padding(10).padding(.trailing, 20)
                    .frame(width: 300, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(width: 340, height: 220),
            frame: CGSize(width: 340, height: 220)
        )
        let paragraphSize = try await fittingSize(
            for: List {
                MarkdownBlockRenderer(markdown: "引用内容")
                    .padding(10).padding(.trailing, 20)
                    .frame(width: 300, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(width: 340, height: 220),
            frame: CGSize(width: 340, height: 220)
        )

        let heightDiff = quoteSize.height - paragraphSize.height
        print("list quote: \(quoteSize.height), list paragraph: \(paragraphSize.height), diff: \(heightDiff)")
        #expect(heightDiff < 30)
    }

    // MARK: - 基础布局

    @Test
    func quoteBlockDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let size = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容").frame(width: 300)
        )
        #expect(size.height < 80)
    }

    @Test
    func quoteInBubbleDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let size = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容")
                .padding(10).padding(.trailing, 20)
                .frame(width: 300, alignment: .leading)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        #expect(size.height < 100)
    }

    @Test
    func quoteInListDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let size = try await fittingSize(
            for: List {
                MarkdownBlockRenderer(markdown: "> 引用内容")
                    .padding(10).padding(.trailing, 20)
                    .frame(width: 300, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(width: 340, height: 220),
            frame: CGSize(width: 340, height: 220)
        )
        #expect(size.height < 260)
    }

    // MARK: - quote 后跟其他 block

    @Test
    func quoteFollowedByParagraphDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let size = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容\n\n后续段落").frame(width: 300)
        )
        #expect(size.height < 150)
    }

    @Test
    func quoteFollowedByCodeBlockDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let size = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: "> 引用内容\n\n```swift\nlet value = 1\n```").frame(width: 300)
        )
        #expect(size.height < 200)
    }

    // MARK: - 长文本 quote

    @Test
    func longQuoteInBubbleDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let markdown = "> 这是一段很长的引用文本，用来测试在消息气泡中渲染引用块时是否会因为 RoundedRectangle 竖线而导致下方出现大量空白。\n> 这是引用的第二行。\n> 这是引用的第三行。"
        let size = try await fittingSize(
            for: MarkdownBlockRenderer(markdown: markdown)
                .padding(10).padding(.trailing, 20)
                .frame(width: 300, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        #expect(size.height < 300)
    }

    @Test
    func longQuoteInListDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let markdown = "> 这是一段很长的引用文本。\n> 这是引用的第二行。\n> 这是引用的第三行。"
        let size = try await fittingSize(
            for: List {
                MarkdownBlockRenderer(markdown: markdown)
                    .padding(10).padding(.trailing, 20)
                    .frame(width: 300, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(width: 340, height: 400),
            frame: CGSize(width: 340, height: 400)
        )
        #expect(size.height < 450)
    }

    // MARK: - 完整消息结构

    @Test
    func quoteInFullMessageDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let markdown = "这是一段普通文本。\n\n> 引用内容\n\n这是另一段普通文本。"
        let size = try await fittingSize(
            for: VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lumi").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("12:00:00").font(.system(size: 11))
                }
                MarkdownBlockRenderer(markdown: markdown)
                    .padding(10).padding(.trailing, 20)
                    .frame(width: 300, alignment: .leading)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .frame(width: 340, alignment: .leading)
        )
        #expect(size.height < 250)
    }

    @Test
    func quoteInListRowDoesNotCreateExcessiveVerticalWhitespace() async throws {
        let markdown = "这是一段普通文本。\n\n> 引用内容\n\n这是另一段普通文本。"
        let size = try await fittingSize(
            for: List {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Lumi").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("12:00:00").font(.system(size: 11))
                    }
                    MarkdownBlockRenderer(markdown: markdown)
                        .padding(10).padding(.trailing, 20)
                        .frame(width: 300, alignment: .leading)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(width: 340, height: 300),
            frame: CGSize(width: 340, height: 300)
        )
        #expect(size.height < 350)
    }

    // MARK: - Helpers

    private func fittingSize<V: View>(
        for view: V,
        frame: CGSize = CGSize(width: 300, height: 1)
    ) async throws -> CGSize {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: frame)
        try await Task.sleep(for: .milliseconds(150))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }
}
