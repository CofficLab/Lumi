import Foundation

public struct EditorStatusToastPresentation: Equatable, Sendable {
    public let level: EditorStatusLevel
    public let duration: TimeInterval
    public let autoDismiss: Bool

    public init(level: EditorStatusLevel, duration: TimeInterval, autoDismiss: Bool) {
        self.level = level
        self.duration = duration
        self.autoDismiss = autoDismiss
    }
}

@MainActor
public enum EditorStatusToastPolicy {
    public static func presentation(
        level: EditorStatusLevel,
        duration: TimeInterval = 1.8
    ) -> EditorStatusToastPresentation {
        let safeDuration = max(1.0, duration)
        switch level {
        case .info:
            return .init(level: .info, duration: safeDuration, autoDismiss: false)
        case .success:
            return .init(level: .success, duration: safeDuration, autoDismiss: false)
        case .warning:
            return .init(level: .warning, duration: max(safeDuration, 2.0), autoDismiss: false)
        case .error:
            return .init(level: .error, duration: max(safeDuration, 2.0), autoDismiss: true)
        }
    }
}
