import Foundation

/// Coordinates background preloading so active workspace indexing takes priority.
@MainActor
public enum SemanticIndexPreloadCoordinator {
    private static var isPaused = false
    private static var resumeTask: Task<Void, Never>?

    public static func pause() {
        isPaused = true
        resumeTask?.cancel()
        resumeTask = nil
    }

    public static func scheduleResume(after delay: TimeInterval = 10) {
        resumeTask?.cancel()
        resumeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isPaused = false
        }
    }

    public static func shouldContinuePreloading(activeProjectPath: String?, projectPath: String) -> Bool {
        if isPaused { return false }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return false }
        if SemanticIndexJobController.shared.hasActiveWorkspaceJob { return false }
        if let activeProjectPath,
           URL(fileURLWithPath: activeProjectPath).standardizedFileURL.path
             == URL(fileURLWithPath: projectPath).standardizedFileURL.path {
            return false
        }
        return true
    }
}
