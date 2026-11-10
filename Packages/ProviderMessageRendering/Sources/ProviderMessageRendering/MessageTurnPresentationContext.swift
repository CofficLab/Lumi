import Foundation
import SwiftUI

/// 消息轮次（turn）的呈现上下文。
///
/// V4（ZCode）把消息按「轮次」组织：轮尾操作栏、整轮复制文本与完成时间
/// 都属于**轮次**，而不是某一条 message。这个结构体通过 SwiftUI Environment
/// 传给渲染层，从而不需要修改第三方 renderer 的 `render` 签名。
///
/// - Important: V1–V3 不注入这个 context（默认 `nil`），行为完全不变。
public struct MessageTurnPresentationContext: Equatable, Sendable {
    /// 轮次的稳定标识（`turn:<uuid>` 或 `message:<uuid>`）。
    public let turnKey: String
    /// 真实存在的 agent 轮次 ID；旧数据可能为 nil。
    public let agentTurnID: UUID?
    /// 该行是否是本轮**轮尾助手正文**（操作栏只挂在这里）。
    public let isTailAssistantText: Bool
    /// 本轮是否仍在运行中。
    public let isRunning: Bool
    /// 整轮复制文本（所有非空助手正文按 `\n\n` 连接）。
    public let assistantCopyText: String
    /// 轮尾正文的真实完成时间；运行中为 nil。
    public let completedAt: Date?

    public init(
        turnKey: String,
        agentTurnID: UUID?,
        isTailAssistantText: Bool,
        isRunning: Bool,
        assistantCopyText: String,
        completedAt: Date?
    ) {
        self.turnKey = turnKey
        self.agentTurnID = agentTurnID
        self.isTailAssistantText = isTailAssistantText
        self.isRunning = isRunning
        self.assistantCopyText = assistantCopyText
        self.completedAt = completedAt
    }
}

public extension EnvironmentValues {
    /// 当前消息所属轮次的呈现上下文；V1–V3 为 nil。
    var messageTurnPresentation: MessageTurnPresentationContext? {
        get { self[MessageTurnPresentationContextKey.self] }
        set { self[MessageTurnPresentationContextKey.self] = newValue }
    }

    /// 当前轮次的**助手段**是否处于 hover 状态；用于控制轮尾操作栏的显隐。
    ///
    /// - Important: 这里只表示「助手段」被悬停。
    ///   用户气泡是**独立的 hover 域**：悬停用户行不会点亮助手操作栏。
    ///
    ///   基准：ZCode 原型用了两个 group ——
    ///   `group/user-row`（`ConversationRowView.tsx`）与
    ///   `group/assistant-turn`（`ConversationTurnGroup.tsx`）。
    ///   之前 Lumi V4 把两者合并成一个整轮 hover，
    ///   导致悬停用户气泡时助手轮尾操作栏也冒出来。
    var messageTurnIsHovered: Bool {
        get { self[MessageTurnIsHoveredKey.self] }
        set { self[MessageTurnIsHoveredKey.self] = newValue }
    }
}

private struct MessageTurnPresentationContextKey: EnvironmentKey {
    static let defaultValue: MessageTurnPresentationContext? = nil
}

private struct MessageTurnIsHoveredKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
