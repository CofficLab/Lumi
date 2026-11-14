import Foundation

/// 一段连续对话内容的不可变摘要块（fold-once 分层压缩的基本单位）。
///
/// 与旧的滚动摘要不同，块一旦产出就不再改写：
/// - tier 1 由原始消息折叠一次而来，`sourceMessageIDs` 记录被折叠的消息；
/// - tier ≥ 2 由更低层的块折叠而来，`sourceBlockIDs` 记录被折叠的块，
///   绝不重新折叠原始历史。每条内容一生只被压缩一次，早期留存不再随回合
///   几何衰减（#1160 Problem 1）。
///
/// 块文本不可变 + 只追加/停用的渲染方式让 provider 前缀缓存在压缩后依然命中
/// （#1160 Problem 2）。血缘指针（`sourceMessageIDs` / `sourceBlockIDs`）让任意块
/// 都能逐层回溯到原始消息，供 `decompress_context` 按需恢复保真度。
struct CompressionBlock: Sendable, Equatable, Identifiable {
    let id: UUID
    let conversationID: UUID
    /// 1 = 折叠原始消息；2+ = 折叠低层块。
    let tier: Int
    /// 不可变摘要正文。
    let summary: String
    /// tier 1：被折叠的原始消息 ID（按时间升序）；tier ≥ 2 为空。
    let sourceMessageIDs: [UUID]
    /// tier ≥ 2：被折叠的低层块 ID（按内容升序）；tier 1 为空。
    let sourceBlockIDs: [UUID]
    /// 本块（传递地）覆盖到的最后一条原始消息 ID，用于确定逐字尾部边界。
    let coveredThroughMessageID: UUID
    let providerID: String?
    let modelName: String?
    let estimatedTokens: Int
    let createdAt: Date
    /// 被更高层折叠后置为 false；渲染只取 active 块。
    var active: Bool
    let schemaVersion: Int

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        tier: Int,
        summary: String,
        sourceMessageIDs: [UUID] = [],
        sourceBlockIDs: [UUID] = [],
        coveredThroughMessageID: UUID,
        providerID: String? = nil,
        modelName: String? = nil,
        estimatedTokens: Int,
        createdAt: Date = Date(),
        active: Bool = true,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.conversationID = conversationID
        self.tier = tier
        self.summary = summary
        self.sourceMessageIDs = sourceMessageIDs
        self.sourceBlockIDs = sourceBlockIDs
        self.coveredThroughMessageID = coveredThroughMessageID
        self.providerID = providerID
        self.modelName = modelName
        self.estimatedTokens = estimatedTokens
        self.createdAt = createdAt
        self.active = active
        self.schemaVersion = schemaVersion
    }
}