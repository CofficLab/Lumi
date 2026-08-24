import DownloadKit

/// Shared queue for every V2 download tool. Keeping this actor instance alive
/// for the plugin lifetime preserves task IDs across download/progress/cancel
/// calls instead of creating one queue per tool invocation.
public enum DownloadRuntime {
    public static let manager = DownloadManager()
}
