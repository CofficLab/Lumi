import Foundation
import SwiftUI

/// 对话输入能力协议
///
/// 管理聊天输入框的当前状态,让内核可以统一持有并观察当前输入内容。
/// 这样插件只是一个实现者,而不是输入内容的唯一所有者,后续可在内核层
/// 扩展草稿恢复、输入预填、输入同步等能力。
@MainActor
public protocol ConversationInputProviding: ObservableObject {
    /// 当前已提交的输入文本。
    ///
    /// IME marked text is owned by the native editor until composition is
    /// committed, so consumers should not expect intermediate pinyin/kana
    /// composition values here.
    var text: String { get set }

    /// 输入框高度
    var inputHeight: CGFloat { get set }

    /// 输入框是否获得焦点
    var isInputFocused: Bool { get set }

    /// 光标位置
    var inputCursorPosition: Int { get set }

    /// 最近一次发送失败时的错误信息
    var errorMessage: String? { get set }

    /// 将文件加入当前输入草稿。
    ///
    /// 典型用途是把文件树/编辑器里的文件路径整理成可发送的引用文本，交给用户
    /// 继续编辑后发送。实现方决定具体呈现格式。
    func addToConversation(fileURLs: [URL], windowId: UUID?)

    /// 当前是否正在发送
    func isSending(kernel: LumiKernel) -> Bool

    /// 是否满足发送条件
    func canSend(kernel: LumiKernel) -> Bool

    /// 发送当前输入内容
    func send(kernel: LumiKernel)

    /// 取消当前发送请求
    func stop(kernel: LumiKernel)
}
