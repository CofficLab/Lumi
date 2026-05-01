import Foundation
import MagicAlert

@MainActor
final class EditorStatusToastController {
    func show(
        message: String,
        level: EditorStatusLevel,
        duration: TimeInterval = 1.8
    ) {
        let safeDuration = max(1.0, duration)
        switch level {
        case .info:
            alert_info(message, duration: safeDuration)
        case .success:
            alert_success(message, duration: safeDuration)
        case .warning:
            alert_warning(message, duration: max(safeDuration, 2.0))
        case .error:
            alert_error(message, duration: max(safeDuration, 2.0), autoDismiss: true)
        }
    }
}
