import CoreServices
import Foundation

/// 使用 FSEventStream 监听 `.git` 目录；具体事件维度由快照比较器判断。
final class GitDirectoryWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    init(url: URL, onChange: @escaping @MainActor () -> Void) throws {
        self.url = url
        self.onChange = onChange
        try start()
    }

    deinit { stop() }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func start() throws {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<GitDirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in watcher.onChange() }
        }
        let paths = [url.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            throw GitDirectoryWatcherError.streamCreationFailed(url.path)
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    private enum GitDirectoryWatcherError: Error {
        case streamCreationFailed(String)
    }
}
