import Foundation

/// `LumiChatKit` turn 结束原因（唯一权威类型）。
public enum LumiTurnEndReason: String, Sendable, Equatable, Codable {
  case completed
  case failed
  case userRejection
  case awaitingUserResponse
  case cancelled

  /// 是否适合触发「自动续聊」类插件（任务推进、队列出队等）。
  public var allowsAutomaticContinuation: Bool {
    self == .completed
  }
}