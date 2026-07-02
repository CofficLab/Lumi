import Foundation

/// 基于消息历史的 Agent Turn 状态推导（纯函数，无副作用）。
///
/// 供 SendQueue / MessageSender / ToolExecutor / TurnLifecycle 等插件共用。
public enum AgentTurnDerivation {
  public static func lastDrivableMessage(in messages: [AgentChatMessage]) -> AgentChatMessage? {
    messages.last { $0.role != .status }
  }

  public static func hasPendingUserMessage(in messages: [AgentChatMessage]) -> Bool {
    messages.contains { $0.role == .user && $0.queueStatus == .pending }
  }

  public static func shouldDequeueNextTurn(messages: [AgentChatMessage], phase: AgentTurnPhase) -> Bool {
    phase == .idle && hasPendingUserMessage(in: messages)
  }

  /// Turn 是否已到达可收尾状态（成功或失败）。
  public static func isTurnComplete(messages: [AgentChatMessage]) -> Bool {
    turnEndReason(messages: messages) != nil
  }

  /// 从消息历史推导 Turn 结束原因；`nil` 表示 Turn 仍在进行中。
  public static func turnEndReason(messages: [AgentChatMessage]) -> TurnEndReason? {
    guard let last = lastDrivableMessage(in: messages) else { return nil }

    switch last.role {
    case .error:
      return .failed(last.content)
    case .assistant:
      if last.isError {
        return .failed(last.content)
      }
      guard last.toolCalls == nil || last.toolCalls?.isEmpty == true else {
        return nil
      }
      return .completed
    case .user, .tool, .system, .status:
      return nil
    }
  }

  public static func shouldRequestLLM(messages: [AgentChatMessage]) -> Bool {
    guard let last = lastDrivableMessage(in: messages) else { return false }
    switch last.role {
    case .user, .tool:
      return true
    case .assistant, .error, .system, .status:
      return false
    }
  }

  public static func shouldExecuteTools(messages: [AgentChatMessage], phase: AgentTurnPhase) -> Bool {
    guard phase == .processing else { return false }
    guard let last = lastDrivableMessage(in: messages), last.role == .assistant else { return false }
    guard let toolCalls = last.toolCalls, !toolCalls.isEmpty else { return false }

    guard let lastIndex = messages.lastIndex(where: { $0.id == last.id }) else { return true }
    let nextIndex = messages.index(after: lastIndex)
    guard nextIndex < messages.endIndex else { return true }
    return !messages[nextIndex...].contains { $0.role == .tool }
  }
}
