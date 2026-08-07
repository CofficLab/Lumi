import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的发送/停止按钮
///
/// 从 composer 中迁出，注册到 ChatActionBar 的 trailing 侧。
/// 根据 `kernel.messageSender` 的发送状态在 `SendButton` 与 `StopButton` 之间切换。
/// 发送逻辑与回车提交共用 `ConversationInputProviding.send(kernel:)`，错误状态也由输入能力统一持有。
struct SendActionBarButton: View {
    // body 把 kernel 作为参数传给 inputState 方法（isSending/canSend/send/stop），
    // 但本视图的刷新信号来自 inputState（ConversationInputService，已 opt-out kernel 总线），
    // 故用 let 而非 @ObservedObject——避免无谓挂上 kernel 全局总线。
    let kernel: LumiKernel
    @ObservedObject var inputState: InputState

    var body: some View {
        if inputState.isSending(kernel: kernel) {
            StopButton(action: { inputState.stop(kernel: kernel) })
                .help("Stop")
        } else {
            SendButton(canSend: inputState.canSend(kernel: kernel), action: { inputState.send(kernel: kernel) })
                .help("Send")
        }
    }
}
