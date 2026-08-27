import Foundation

/// Describes the mutually exclusive send/stop controls for the action bar.
struct SendActionBarState {
    var isSending: Bool
    var canSend: Bool

    var showsSendButton: Bool { !isSending }
    var showsStopButton: Bool { isSending }
}
