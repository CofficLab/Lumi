import Foundation
import MagicKit
import os

/// 文件树目录变化监听器
/// 使用 DispatchSource 监控根目录及已展开子目录的文件系统变化，
/// 检测到变化后通知 FileTreeDataSource 进行增量刷新。
///
/// 注意：所有公开方法应在 MainActor 上调用以确保线程安全。
final class FileTreeWatcher: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "🌲"
    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-native.watcher")

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
    /// 确保所有操作都在同一线程（MainActor）上执行
    private let queue = DispatchQueue.main

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
            DispatchQueue.main.async {
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

    /// 更新监控列表：根据当前展开的节点，添加新的监控，移除不再需要的监控
    func updateWatchedNodes(expandedNodes: [FileNode], rootURL: URL) {
        var desiredPaths = Set<String>()
        desiredPaths.insert(rootURL.standardizedFileURL.path)
        for node in expandedNodes {
            if node.isDirectory {
                desiredPaths.insert(node.url.standardizedFileURL.path)
            }
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
}
