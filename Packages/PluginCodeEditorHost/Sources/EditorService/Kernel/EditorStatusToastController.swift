import Foundation
import MagicAlert

@MainActor
final class EditorStatusToastController {
    func show(
        message: String,
        level: EditorStatusLevel,
        duration: TimeInterval = 1.8
    ) {
        let presentation = EditorStatusToastPolicy.presentation(level: level, duration: duration)
        switch presentation.level {
        case .info:
            alert_info(message, duration: presentation.duration)
        case .success:
            alert_success(message, duration: presentation.duration)
        case .warning:
            alert_warning(message, duration: presentation.duration)
        case .error:
            alert_error(message, duration: presentation.duration, autoDismiss: presentation.autoDismiss)
        }
    }
}
