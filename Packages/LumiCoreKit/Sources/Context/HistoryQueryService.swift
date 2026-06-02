import Foundation

/// 历史数据查询服务
///
/// 定义插件查询消息和对话历史所需的全部能力。
/// 协议定义在 `LumiCoreKit`，由内核在运行时注入具体实现。
///
/// ## 设计原则
///
/// - 只暴露 **what**（查询什么），不暴露 **how**（SwiftData / CoreData 等实现细节）
/// - 返回轻量 DTO（如 `HistoryMessageRow`），不返回内核 Entity
/// - 所有方法均支持异步调用，避免阻塞主线程
public protocol HistoryQueryService: Sendable {
    /// 查询消息总数
    func fetchMessageCount() async -> Int

    /// 分页查询消息（按时间倒序，最新消息在前）
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    /// - Returns: 当前页消息数据
    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow]

    /// 查询对话总数
    func fetchConversationCount() async -> Int

    /// 分页查询对话（按更新时间倒序，最近更新的在前）
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    /// - Returns: 当前页对话数据
    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow]
}
