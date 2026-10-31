import Foundation

// MARK: - Collapsed content blocks（消息元数据）

/// 消息正文中被折叠成 chip 的一段内容。
///
/// 输入框把大段粘贴内容渲染成一行内联 chip，但发给上层的文本是**拍平后的完整
/// 文本**。若不额外记录，消息落库后只剩一长串纯文字，渲染层无法再还原成 chip。
/// 本类型记录这段内容在 `Message.content` 中的区间，渲染层据此把区间替换成
/// 可点击展开的 chip。
///
/// - Important: `start` / `length` 是 **Character 偏移**（Swift `String.Index`
///   语义），不是 UTF-16。落库前必须经
///   ``CollapsedContentBlockMetadata/normalized(_:contentLength:)`` 归一化，
///   避免正文改动后区间越界。
public struct CollapsedContentBlock: Codable, Equatable, Sendable, Identifiable {
    /// 在 `Message.content` 中的起始 Character 偏移。
    public let start: Int
    /// 折叠段长度（Character 数）。
    public let length: Int
    /// chip 上显示的一行标题（如「粘贴的文本」或来源文件名）。
    public let title: String
    /// chip 图标（SF Symbol 名）。缺省时渲染层按 `title` 回退。
    public let systemImage: String?

    /// 稳定标识。同一段内容在同一消息内唯一，用 `start` 即可保证。
    public var id: Int { start }

    public init(start: Int, length: Int, title: String, systemImage: String? = nil) {
        self.start = start
        self.length = length
        self.title = title
        self.systemImage = systemImage
    }
}

// MARK: - Metadata codec

/// `Message.metadata` 中折叠块的编解码。
///
/// - key `collapsedBlocks` → `[CollapsedContentBlock]` JSON
/// - 旧数据没有该 key 时解码为空数组，渲染层退化为纯文本展示。
public enum CollapsedContentBlockMetadata {
    public static let collapsedBlocksKey = "collapsedBlocks"

    // MARK: Encode

    public static func encodeCollapsedBlocks(
        _ blocks: [CollapsedContentBlock]
    ) -> [String: String] {
        guard !blocks.isEmpty,
              let data = try? JSONEncoder().encode(blocks),
              let string = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return [collapsedBlocksKey: string]
    }

    // MARK: Decode

    public static func decodeCollapsedBlocks(
        from metadata: [String: String]
    ) -> [CollapsedContentBlock] {
        guard let string = metadata[collapsedBlocksKey],
              let data = string.data(using: .utf8),
              let blocks = try? JSONDecoder().decode([CollapsedContentBlock].self, from: data) else {
            return []
        }
        return blocks
    }

    /// 按正文长度归一化区间，丢弃越界与重叠的块。
    ///
    /// 正文可能被编辑或 trim 过，落库的偏移未必仍然成立。渲染层直接信任
    /// metadata 会在正文变短后切出越界区间，因此**解码即校验**。
    public static func normalizedBlocks(
        from metadata: [String: String],
        contentLength: Int
    ) -> [CollapsedContentBlock] {
        normalized(decodeCollapsedBlocks(from: metadata), contentLength: contentLength)
    }

    /// 按正文长度归一化区间，丢弃越界与重叠的块。
    ///
    /// 相邻块若区间重叠，后一个整体丢弃：重叠意味着正文已变，无法判断
    /// 哪个区间仍然代表原折叠段，猜错比不渲染更糟。
    public static func normalized(
        _ blocks: [CollapsedContentBlock],
        contentLength: Int
    ) -> [CollapsedContentBlock] {
        let clamped = blocks
            .filter { $0.start >= 0 && $0.length > 0 && $0.start + $0.length <= contentLength }
            .sorted { $0.start < $1.start }

        var result: [CollapsedContentBlock] = []
        var lastEnd = -1
        for block in clamped {
            guard block.start >= lastEnd else { continue }
            result.append(block)
            lastEnd = block.start + block.length
        }
        return result
    }

    /// 把正文开头的空白裁掉后，同步平移所有区间。
    ///
    /// 发送链路会 trim 正文（`trimmingCharacters(in: .whitespacesAndNewlines)`），
    /// 区间以未 trim 的文本为基准。不平移的话，首行的 chip 在消息里会整体错位。
    public static func rebased(
        _ blocks: [CollapsedContentBlock],
        droppingLeadingWhitespaceOf content: String
    ) -> [CollapsedContentBlock] {
        let dropped = content.prefix(while: { $0.isWhitespace || $0.isNewline }).count
        guard dropped > 0 else { return blocks }
        return blocks.compactMap { block in
            let start = block.start - dropped
            guard start >= 0 else { return nil }
            return CollapsedContentBlock(
                start: start,
                length: block.length,
                title: block.title,
                systemImage: block.systemImage
            )
        }
    }
}
