import LumiLocalizationKit
import LumiUI
import ProviderMessage
import SwiftUI

/// 消息行的统一右键菜单。
///
/// V1–V5 五个消息列表共用这一个组件，保证各版本的右键菜单行为一致：
/// - 「复制消息」：复制消息正文（无正文时回退到原始字段描述）。
/// - 「重新发送」：仅用户消息且有正文时提供。
/// - 「停止」：仅当该消息所属会话的回合处于 running / suspended 时提供。
///
/// - Important: 「停止」用的是**消息自身**的 `conversationID`，
///   不是当前选中会话。用户可能正在浏览历史会话的消息列表，
///   此时右键历史消息仍应能停掉那个会话的回合。
/// - Important: 「停止」的可见性由回合状态决定，而非消息角色。
///   助手消息、工具消息等同样可能属于一个正在跑的会话。
/// - Important: 菜单内容在**右键打开的那一刻**才求值，
///   因此「停止」反映的是用户右键当下的真实回合状态，
///   而不是视图最后一次重绘时的快照。
struct MessageContextMenu: View {
    let capability: (any MessageRendererCapability)?
    let message: Message

    var body: some View {
        Button {
            copyMessageContent()
        } label: {
            Label(pluginLocalization.string("复制消息"), systemImage: "doc.on.doc")
        }

        if showsResend {
            Button {
                Task {
                    await capability?.resendMessage(
                        content: message.content,
                        conversationID: message.conversationID
                    )
                }
            } label: {
                Label(pluginLocalization.string("重新发送"), systemImage: "arrow.clockwise")
            }
        }

        if canStop {
            Button {
                capability?.stopTurn(conversationID: message.conversationID)
            } label: {
                Label(pluginLocalization.string("停止"), systemImage: "stop.circle")
            }
        }
    }

    /// 是否提供「重新发送」。
    ///
    /// 只对**用户消息**有意义——重新发送的是用户自己写的内容。
    /// 助手 / 工具 / 错误消息的内容不是用户输入的，重发没有语义。
    var showsResend: Bool {
        capability != nil
            && message.role == .user
            && !message.content.isEmpty
    }

    /// 该消息所属会话当前是否可以被停止。
    ///
    /// 抽成纯函数以便单元测试直接覆盖判定：回合必须处于
    /// running（正在跑）或 suspended（等授权 / 等回答）。
    /// 两者都是「还有没干完的活」，口径与 `ConversationStateSnapshot.canStop` 一致。
    static func canStop(
        message: Message,
        capability: (any MessageRendererCapability)?
    ) -> Bool {
        capability?.canStopTurn(conversationID: message.conversationID) == true
    }

    private var canStop: Bool {
        Self.canStop(message: message, capability: capability)
    }

    private func copyMessageContent() {
        LumiPasteboard.copyString(MessageViewHelpers.copyContent(for: message))
    }

    // MARK: - 挂载

    /// 给一条消息的渲染结果挂上统一右键菜单。
    ///
    /// - Important: 菜单挂在这里（渲染注册层）而不是各个具体视图里，
    ///   是为了让 V1–V5 所有消息行——包括 V4/V5 那些**不使用**
    ///   `MessageViewChrome` 的独立渲染器（ZCode / ChatGPT 气泡与正文）——
    ///   拥有完全一致的右键行为。挂视图内部会漏掉绕过 chrome 的那一批。
    static func attach(
        to view: AnyView,
        capability: (any MessageRendererCapability)?,
        message: Message
    ) -> AnyView {
        AnyView(
            view.contextMenu {
                MessageContextMenu(capability: capability, message: message)
            }
        )
    }
}
