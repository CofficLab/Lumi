import Foundation

/// Describes the mutually exclusive send/stop controls for the action bar.
struct SendActionBarState {
    /// 该会话是否还有未完成的回合（运行中，或挂在等用户授权/回答）。
    ///
    /// - Important: 停止按钮的可见性由它决定，而不是「是否正在产出」。
    ///   挂起等待用户时回合同样没干完，用户必须能停它。
    var canStop: Bool
    var canSend: Bool

    var showsSendButton: Bool { !canStop }
    var showsStopButton: Bool { canStop }
}
