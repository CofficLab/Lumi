import LumiKernel
import LumiUI
import SwiftUI

/// Action Bar 上的发送/停止按钮
struct SendActionBarButton: View {
    @ObservedObject var kernel: LumiKernel
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
