import Foundation

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
