import Foundation

/// Agent Turn 结束原因（插件管线与通知层共用）。
public enum TurnEndReason: Sendable, Equatable {
  case completed
  case failed(String)
  case userRejection
  case awaitingUserResponse
  case cancelled
}

/// `LumiChatKit` turn 结束原因（与 `TurnEndReason` 对齐，供通知与 outcome 使用）。
public enum LumiTurnEndReason: String, Sendable, Equatable, Codable {
  case completed
  case failed
  case userRejection
  case awaitingUserResponse
  case cancelled

  public init(_ reason: TurnEndReason) {
    switch reason {
    case .completed:
      self = .completed
    case .failed:
      self = .failed
    case .userRejection:
      self = .userRejection
    case .awaitingUserResponse:
      self = .awaitingUserResponse
    case .cancelled:
      self = .cancelled
    }
  }

  /// 是否适合触发「自动续聊」类插件（任务推进、队列出队等）。
  public var allowsAutomaticContinuation: Bool {
    self == .completed
  }
}
