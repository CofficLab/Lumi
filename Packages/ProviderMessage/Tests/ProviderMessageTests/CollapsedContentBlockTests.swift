import Foundation
import Testing
@testable import ProviderMessage

@Suite("CollapsedContentBlock")
struct CollapsedContentBlockTests {
    @Test("折叠块可编码进 metadata 并原样解码")
    func encodesAndDecodesBlocks() {
        let blocks = [
            CollapsedContentBlock(start: 0, length: 120, title: "粘贴的文本", systemImage: "doc.on.clipboard"),
            CollapsedContentBlock(start: 130, length: 40, title: "main.swift"),
        ]
        let metadata = CollapsedContentBlockMetadata.encodeCollapsedBlocks(blocks)

        #expect(metadata[CollapsedContentBlockMetadata.collapsedBlocksKey] != nil)
        #expect(CollapsedContentBlockMetadata.decodeCollapsedBlocks(from: metadata) == blocks)
    }

    @Test("旧数据没有该 key 时解码为空数组")
    func decodesEmptyForLegacyData() {
        #expect(CollapsedContentBlockMetadata.decodeCollapsedBlocks(from: [:]).isEmpty)
        #expect(
            CollapsedContentBlockMetadata.normalizedBlocks(
                from: [:],
                contentLength: 100
            ).isEmpty
        )
    }

    @Test("空数组不写入 metadata，避免留下无意义的空 JSON")
    func encodesNothingForEmptyBlocks() {
        #expect(CollapsedContentBlockMetadata.encodeCollapsedBlocks([]).isEmpty)
    }

    @Test("越界区间被丢弃")
    func dropsOutOfRangeBlocks() {
        let metadata = CollapsedContentBlockMetadata.encodeCollapsedBlocks([
            CollapsedContentBlock(start: 50, length: 100, title: "越界"),
        ])
        // 正文只有 60 个字符，区间 [50, 150) 越界。
        let normalized = CollapsedContentBlockMetadata.normalizedBlocks(
            from: metadata,
            contentLength: 60
        )
        #expect(normalized.isEmpty)
    }

    @Test("重叠区间只保留靠前的一个")
    func dropsOverlappingBlocks() {
        let metadata = CollapsedContentBlockMetadata.encodeCollapsedBlocks([
            CollapsedContentBlock(start: 0, length: 20, title: "A"),
            CollapsedContentBlock(start: 10, length: 20, title: "B"),
        ])
        let normalized = CollapsedContentBlockMetadata.normalizedBlocks(
            from: metadata,
            contentLength: 100
        )
        #expect(normalized.count == 1)
        #expect(normalized.first?.title == "A")
    }

    @Test("正文裁掉开头空白后，区间同步平移")
    func rebasesBlocksAfterLeadingWhitespaceDrop() {
        let blocks = [CollapsedContentBlock(start: 10, length: 20, title: "A")]
        let rebased = CollapsedContentBlockMetadata.rebased(
            blocks,
            droppingLeadingWhitespaceOf: "  \n  hello world"
        )
        #expect(rebased.count == 1)
        #expect(rebased.first?.start == 5)
    }

    @Test("正文没有前导空白时区间保持不变")
    func keepsBlocksWhenNoLeadingWhitespace() {
        let blocks = [CollapsedContentBlock(start: 3, length: 5, title: "A")]
        let rebased = CollapsedContentBlockMetadata.rebased(
            blocks,
            droppingLeadingWhitespaceOf: "hello"
        )
        #expect(rebased == blocks)
    }
}
