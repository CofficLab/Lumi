import Foundation

// MARK: - Legacy Data Capability Protocol

/// 旧版本(v4)数据读取能力协议 - 迁移专用只读接口
///
/// 用于「跨大版本数据迁移」场景:当 App 从 v4 升级到 v5 时,每个 Store 插件
/// (ConversationStorePlugin / MessageStorePlugin)在自己的 `onReady` 阶段
/// 通过本协议读取 v4 旧库里与自己相关的数据,转换后写入 v5 新库。
///
/// # 设计要点
/// - **只读**:本协议只暴露 fetch 方法,绝不写旧库。
/// - **单点打开**:由实现类负责「复制副本 + 打开一次」,避免多个插件各自打开
///   同一个 v4 旧库造成 SQLite 锁竞争或文件损坏。各插件只调用本协议的 fetch API。
/// - **中性 DTO**:返回 `LumiConversationSummary` / `LumiChatMessage` 等内核通用
///   类型(与存储无关),消费插件无需感知 v4 的 SwiftData `@Model` 定义。
/// - **可选服务**:本服务不参与内核启动校验(非必需)。只有迁移期由
///   `LegacyDataPlugin` 在 `onBoot` 注册;迁移窗口期结束后可整体移除。
///
/// # 消费示例
/// ```swift
/// public func onReady(kernel: LumiKernel) async throws {
///     // 1. 建空新库 ...
///     // 2. 迁移(幂等 + 吞错,绝不向上抛)
///     do {
///         guard migrationMarkerExists() == false else { return }
///         guard let legacy = kernel.legacyData else { return }
///         if legacy.hasLegacyData() == false { return }
///         let conversations = try legacy.fetchLegacyConversations()
///         // 转换并写入新库 ...
///         writeMigrationMarker()
///     } catch {
///         logger.error("迁移失败,已跳过: \(error.localizedDescription)")
///     }
/// }
/// ```
@MainActor
public protocol LegacyDataProviding: AnyObject {
    /// 旧版本数据根目录(原件)
    ///
    /// 由实现类自行计算 v4 路径(如 `db_production_v4`),不依赖当前版本的
    /// `StorageProviding.dataRootDirectory`(后者已指向 v5)。返回 nil 表示
    /// 未找到旧版本数据(全新安装)。
    var legacyDataRootDirectory: URL? { get }

    /// 是否存在可迁移的旧版本数据
    ///
    /// 轻量探测(路径存在性检查),不打开数据库。消费插件可据此快速跳过。
    func hasLegacyData() -> Bool

    /// 读取 v4 历史会话
    ///
    /// 返回与存储无关的 `LumiConversationSummary`(UUID / Date 等通用类型原样保留)。
    /// 消费插件用 `ConversationModel.from(summary:)` 转换写入新库。
    ///
    /// - Important: 实现类负责「复制旧库副本后只读打开」,保证不损坏原件。
    /// - Throws: `LegacyDataError`(snapshotCopyFailed / openFailed / fetchFailed)。
    func fetchLegacyConversations() throws -> [LumiConversationSummary]

    /// 读取指定会话下的 v4 历史消息
    ///
    /// 返回与存储无关的 `LumiChatMessage`。其中工具调用(token 统计、tool calls)
    /// 已合并进单条消息对象 —— 对应 v5 `MessageModel` 的扁平化结构,无需额外迁移
    /// 独立的 ToolCallEntity / MessageMetricsEntity 表。
    ///
    /// - Parameter conversationID: v4 会话的原始 UUID(与 `LumiConversationSummary.id` 一致)。
    /// - Important: 实现类保证使用同一份只读快照。
    /// - Throws: `LegacyDataError`。
    func fetchLegacyMessages(for conversationID: UUID) throws -> [LumiChatMessage]

    /// 释放旧库快照资源
    ///
    /// 所有消费插件完成迁移后调用。实现类可关闭只读 `ModelContext` / 删除临时副本。
    /// 幂等:多次调用安全。
    func releaseLegacySnapshot()
}
