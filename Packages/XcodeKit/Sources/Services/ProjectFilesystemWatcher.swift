import Foundation

/// Watches project files that invalidate semantic indexing.
@MainActor
public final class ProjectFilesystemWatcher {
    public var onNeedsResync: (() -> Void)?

    private var sources: [DispatchSourceFileSystemObject] = []
    private var watchedPaths: Set<String> = []
    private var debounceTask: Task<Void, Never>?

    public init() {}

    public func watch(workspaceURL: URL) {
        stop()
        let paths = Self.watchPaths(for: workspaceURL)
        let fileManager = FileManager.default
        for path in paths where fileManager.fileExists(atPath: path) {
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .attrib],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.scheduleNeedsResync()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
            sources.append(source)
            watchedPaths.insert(path)
        }
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
        watchedPaths.removeAll()
    }

    private func scheduleNeedsResync() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            // Coalesce bursts of structural edits (adding/removing files, toggling build settings in
            // Xcode) into a single re-index. A short debounce fired a full incremental build on every
            // edit; 15s lets a sequence of pbxproj mutations settle before triggering one build.
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            self?.onNeedsResync?()
        }
    }

    public static func watchPaths(for workspaceURL: URL) -> [String] {
        var paths: [String] = []
        switch workspaceURL.pathExtension {
        case "xcodeproj":
            paths.append(workspaceURL.appendingPathComponent("project.pbxproj").path)
        case "xcworkspace":
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: workspaceURL,
                includingPropertiesForKeys: nil
            ) {
                for project in contents where project.pathExtension == "xcodeproj" {
                    paths.append(project.appendingPathComponent("project.pbxproj").path)
                }
            }
        default:
            break
        }
        let packageResolved = workspaceURL.deletingLastPathComponent()
            .appendingPathComponent("Package.resolved")
        if FileManager.default.fileExists(atPath: packageResolved.path) {
            paths.append(packageResolved.path)
        }
        return paths
    }
}
