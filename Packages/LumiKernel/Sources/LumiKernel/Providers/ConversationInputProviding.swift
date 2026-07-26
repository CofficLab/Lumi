import SwiftUI

/// 对话输入能力协议
///
/// 管理聊天输入框的当前状态,让内核可以统一持有并观察当前输入内容。
/// 这样插件只是一个实现者,而不是输入内容的唯一所有者,后续可在内核层
/// 扩展草稿恢复、输入预填、输入同步等能力。
@MainActor
public protocol ConversationInputProviding: ObservableObject {
    /// 当前输入文本
    var text: String { get set }

    /// 输入框高度
    var inputHeight: CGFloat { get set }

    /// 输入框是否获得焦点
    var isInputFocused: Bool { get set }

    /// 光标位置
    var inputCursorPosition: Int { get set }

    /// 最近一次发送失败时的错误信息
    var errorMessage: String? { get set }

    /// 当前是否正在发送
    func isSending(kernel: LumiKernel) -> Bool

    /// 是否满足发送条件
    func canSend(kernel: LumiKernel) -> Bool

    /// 发送当前输入内容
    func send(kernel: LumiKernel)

    /// 取消当前发送请求
    func stop(kernel: LumiKernel)
}
