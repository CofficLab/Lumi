import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的发送/停止按钮
///
/// 从 composer 中迁出，注册到 ChatActionBar 的 trailing 侧。
/// 根据 `kernel.messageSender` 的发送状态在 `SendButton` 与 `StopButton` 之间切换。
/// 发送逻辑与回车提交共用 `InputState.send(kernel:)`，错误状态也由 `InputState` 统一持有。
struct SendActionBarButton: View {
    @ObservedObject var kernel: LumiKernel
    @ObservedObject var inputState: InputState

    private var isSending: Bool {
        inputState.isSending(kernel: kernel)
    }

    private var canSend: Bool {
        inputState.canSend(kernel: kernel)
    }

    var body: some View {
        if isSending {
            StopButton(action: { inputState.stop(kernel: kernel) })
                .help("Stop")
        } else {
            SendButton(canSend: canSend, action: { inputState.send(kernel: kernel) })
                .help("Send")
        }
    }
}
