import Foundation

/// 消息队列状态
enum MessageQueueStatus: String, Codable, Sendable, Equatable {
    /// 待发送
    case pending
    /// 处理中
    case processing
}