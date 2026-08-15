import KernelLumi
import LumiUI
import SwiftUI

/// Action Bar 上的发送/停止按钮
struct SendActionBarButton: View {
    @ObservedObject var kernel: KernelLumi
    @ObservedObject var inputState: InputState

    var body: some View {
        let state = SendActionBarState(
            isSending: inputState.isSending(kernel: kernel),
            canSend: inputState.canSend(kernel: kernel)
        )

        HStack(spacing: 6) {
            if state.showsSendButton {
                SendButton(canSend: state.canSend, action: { inputState.send(kernel: kernel) })
                    .help(LumiPluginLocalization.string("Send", bundle: .module))
            }

            if state.showsStopButton {
                StopButton(action: { inputState.stop(kernel: kernel) })
                    .help(LumiPluginLocalization.string("Stop", bundle: .module))
            }
        }
    }
}

/// Keeps the queue affordance visible while a turn is running.
///
/// Sending another non-empty draft during an active turn enqueues it in
/// `MessageSender`; the stop control is an additional action, not a replacement
/// for the send control.
struct SendActionBarState {
    let isSending: Bool
    let canSend: Bool

    var showsSendButton: Bool { true }
    var showsStopButton: Bool { isSending }
}
