import Foundation
import MagicKit
import os

/// SwiftUI 文件树的目录变化监听器
/// 使用 DispatchSource 监控目录的文件系统变化，
/// 检测到变化后通过回调通知视图刷新。
///
/// 注意：所有公开方法应在 MainActor 上调用以确保线程安全。
final class ProjectTreeWatcher: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌳"
    nonisolated static let verbose = true
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.watcher")

    // MARK: - Types

    /// 目录变化回调，参数为发生变化的目录 URL
    typealias OnDirectoryChanged = @Sendable (URL) -> Void

    /// 单个目录的监控状态
    private struct Watch {
        let fileDescriptor: Int32
        let source: DispatchSourceProtocol
    }

    // MARK: - Properties

    private var watches: [String: Watch] = [:]
    private let onChange: OnDirectoryChanged
    /// 防抖：同一个目录短时间内可能触发多次回调，合并为一次
    private var pendingRefreshes: [String: Task<Void, Never>] = [:]
    private let debounceInterval: UInt64 = 300_000_000 // 0.3 秒

    // MARK: - Init

    init(onChange: @escaping @Sendable (URL) -> Void) {
        self.onChange = onChange
    }

    deinit {
        for (_, watch) in watches {
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)
        }
    }

    // MARK: - Public（必须在 MainActor 调用）

    /// 开始监控指定目录
    func startWatching(url: URL) {
        let key = url.standardizedFileURL.path
        guard watches[key] == nil else { return }

        let fd = Darwin.open(key, O_EVTONLY)
        guard fd >= 0 else {
            Self.logger.warning("\(Self.t)⚠️ 无法打开文件描述符监控目录：\(key)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .global(qos: .utility)
        )

        let onChange = self.onChange
        source.setEventHandler {
            let capturedURL = url
            Task { @MainActor [weak self] in
                guard let self else { return }

                // 防抖处理
                let key = capturedURL.standardizedFileURL.path
                self.pendingRefreshes[key]?.cancel()
                self.pendingRefreshes[key] = Task {
                    try? await Task.sleep(nanoseconds: self.debounceInterval)
                    self.pendingRefreshes.removeValue(forKey: key)
                }

                onChange(capturedURL)
            }
        }

        source.resume()
        watches[key] = Watch(fileDescriptor: fd, source: source)
    }

    /// 停止监控指定目录
    func stopWatching(url: URL) {
        let key = url.standardizedFileURL.path
        guard let watch = watches.removeValue(forKey: key) else { return }
        watch.source.cancel()
        Darwin.close(watch.fileDescriptor)
        pendingRefreshes[key]?.cancel()
        pendingRefreshes.removeValue(forKey: key)
    }

    /// 停止所有监控
    func stopAll() {
        for (_, watch) in watches {
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)
        }
        watches.removeAll()
        for (_, task) in pendingRefreshes {
            task.cancel()
        }
        pendingRefreshes.removeAll()
    }

    /// 更新监控列表：添加新的监控，移除不再需要的监控
    func updateWatchedURLs(_ urls: [URL]) {
        var desiredPaths = Set<String>()
        for url in urls {
            desiredPaths.insert(url.standardizedFileURL.path)
        }

        let currentPaths = Set(watches.keys)
        for path in currentPaths where !desiredPaths.contains(path) {
            if let watch = watches.removeValue(forKey: path) {
                watch.source.cancel()
                Darwin.close(watch.fileDescriptor)
            }
            pendingRefreshes[path]?.cancel()
            pendingRefreshes.removeValue(forKey: path)
        }

        for path in desiredPaths {
            let url = URL(fileURLWithPath: path)
            startWatching(url: url)
        }
    }

    // MARK: - Private

    /// 防抖处理：短时间内同一目录的多次变化合并为一次
    @MainActor
    private func handleDebouncedChange(url: URL) {
        let key = url.standardizedFileURL.path
        pendingRefreshes[key]?.cancel()
        pendingRefreshes[key] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceInterval)
            // onChange 已经在 setEventHandler 中直接调用了
            pendingRefreshes.removeValue(forKey: key)
        }
    }
}
