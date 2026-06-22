import Foundation

/// 基于 `LumiChatMessage` 的 Turn 推导（供 `LumiChatKit` 与聊天侧插件使用）。
public enum LumiAgentTurnDerivation {
  public static func turnMessagesSinceLastUser(in messages: [LumiChatMessage]) -> [LumiChatMessage] {
    guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else {
      return []
    }
    return Array(messages[(lastUserIndex + 1)...]).filter { $0.role != .status }
  }

  public static func lastDrivableMessage(in messages: [LumiChatMessage]) -> LumiChatMessage? {
    messages.last { $0.role != .status }
  }

  /// 从完整会话消息推导最近一次 Turn 的结束原因。
  public static func turnEndReason(in messages: [LumiChatMessage]) -> LumiTurnEndReason? {
    let turnMessages = turnMessagesSinceLastUser(in: messages)
    guard let last = turnMessages.last else { return nil }

    switch last.role {
    case .error:
      return .failed
    case .assistant:
      if last.isError {
        return .failed
      }
      guard last.toolCalls == nil || last.toolCalls?.isEmpty == true else {
        return nil
      }
      return .completed
    case .user, .tool, .system, .status:
      return nil
    }
  }

  public static func assistantCalledTool(named toolName: String, in turnMessages: [LumiChatMessage]) -> Bool {
    turnMessages.contains { message in
      guard message.role == .assistant, let toolCalls = message.toolCalls else { return false }
      return toolCalls.contains { $0.name == toolName }
    }
  }
}
