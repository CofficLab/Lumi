import Foundation

/// A chapter within a story.
public struct Chapter: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let storyID: UUID
    public var title: String

    /// 章节正文。
    ///
    /// - Important: 变更时同步刷新 ``wordCount``。字��统计原先是每次求值都
    ///   重新遍历全文的计算属性，而章节编辑页的 body 会在每次按键后重跑
    ///   （见 issue #1295）。
    public var content: String {
        didSet { wordCount = Self.countWords(content) }
    }

    public var status: ChapterStatus
    public var targetWordCount: Int
    public let createdAt: Date
    public var updatedAt: Date

    /// 缓存的非空白字符数。
    ///
    /// 与 ``content`` 同步维护，读取为 O(1)。派生数据，不参与编码；
    /// 解码后由 ``init(from:)`` 重新计算。
    ///
    /// - Note: 它完全由 `content` 决定，因此参与 `Hashable` 合成不改变语义。
    public private(set) var wordCount: Int

    /// 编码键。`wordCount` 是派生数据，故意排除。
    enum CodingKeys: String, CodingKey {
        case id
        case storyID
        case title
        case content
        case status
        case targetWordCount
        case createdAt
        case updatedAt
    }

    /// Rough Chinese-friendly word count: count non-whitespace characters.
    ///
    /// 用 `reduce` 而非 `filter { }.count`：后者会构造 `Character` 数组再拼接成
    /// 新字符串，在长章节上是可观的额外分配。
    static func countWords(_ content: String) -> Int {
        content.reduce(into: 0) { count, character in
            if !character.isWhitespace {
                count += 1
            }
        }
    }

    public init(
        id: UUID = UUID(),
        storyID: UUID,
        title: String,
        content: String = "",
        status: ChapterStatus = .draft,
        targetWordCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.storyID = storyID
        self.title = title
        self.content = content
        self.status = status
        self.targetWordCount = targetWordCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        // `init` 里的赋值不触发 `didSet`，这里显式补算。
        self.wordCount = Self.countWords(content)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storyID = try container.decode(UUID.self, forKey: .storyID)
        title = try container.decode(String.self, forKey: .title)
        let content = try container.decode(String.self, forKey: .content)
        self.content = content
        status = try container.decode(ChapterStatus.self, forKey: .status)
        targetWordCount = try container.decode(Int.self, forKey: .targetWordCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // 派生数据不入编码，解码后补算。
        self.wordCount = Self.countWords(content)
    }
}
