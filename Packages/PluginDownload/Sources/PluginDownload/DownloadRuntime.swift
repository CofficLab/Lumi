import KitDownload

/// Shared queue for every V2 download tool. Keeping this actor instance alive
/// for the plugin lifetime preserves task IDs across download/progress/cancel
/// calls instead of creating one queue per tool invocation.
public enum DownloadRuntime {
    public static let manager = DownloadManager()
    public static let tasks = DownloadTaskRegistry()
}

public actor DownloadTaskRegistry {
    private var tasks: [String: DownloadTask] = [:]
    public func remember(_ task: DownloadTask) { tasks[task.id] = task }
    public func task(id: String) -> DownloadTask? { tasks[id] }
}
