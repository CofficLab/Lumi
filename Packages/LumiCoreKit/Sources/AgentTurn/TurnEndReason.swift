import Foundation

/// 两个 turn 结束原因枚举语义重叠：保留 `LumiTurnEndReason` 为唯一权威类型
/// （String rawValue，对外稳定，被通知 userInfo 序列化依赖）；`TurnEndReason` 软废弃过渡。
/// 详见 `docs/architecture-refactor-proposal.md` §5 阶段 0。

/// Agent Turn 结束原因（**已软废弃**，新代码请使用 `LumiTurnEndReason`）。
@available(*, deprecated, message: "使用 LumiTurnEndReason；新代码勿用本类型", renamed: "LumiTurnEndReason")
public enum TurnEndReason: Sendable, Equatable {
  case completed
  case failed(String)
  case userRejection
  case awaitingUserResponse
  case cancelled
}

/// `LumiChatKit` turn 结束原因（唯一权威类型）
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
