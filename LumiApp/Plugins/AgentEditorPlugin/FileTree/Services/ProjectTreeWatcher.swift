import Foundation
import os
import MagicKit

/// 文件树目录变化监听器
///
/// 使用 DispatchSource 监控已展开目录的文件系统变化，
/// 检测到变化后通过回调通知上层进行刷新。
///
/// 设计原则：
/// - 仅监听当前已展开的目录（懒监听，避免不必要的系统开销）
/// - 同一目录短时间内多次事件会合并（防抖）
/// - 所有公开方法线程安全
final class ProjectTreeWatcher: @unchecked Sendable, SuperLog {

    // MARK: - Types

    /// 目录变化回调，参数为发生变化的目录 URL
    typealias OnDirectoryChanged = @Sendable (URL) -> Void

    /// 单个目录的监控状态
    private struct Watch {
        let fileDescriptor: Int32
        let source: DispatchSourceProtocol
    }

    // MARK: - Properties

    nonisolated static let emoji = "🌳"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.watcher")

    /// 当前活跃的监控，key 为标准化路径
    private var watches: [String: Watch] = [:]

    /// 目录变化回调
    private let onChange: OnDirectoryChanged

    /// 防抖任务：同一个目录短时间内可能触发多次回调，合并为一次
    private var pendingRefreshes: [String: Task<Void, Never>] = [:]

    /// 防抖间隔（秒）
    private let debounceInterval: UInt64

    /// 操作队列，确保 watches 字典的读写安全
    private let queue = DispatchQueue(label: "ProjectTreeWatcher.queue", qos: .utility)

    // MARK: - Init

    /// 初始化监听器
    /// - Parameters:
    ///   - debounceInterval: 防抖间隔（纳秒），默认 0.3 秒
    ///   - onChange: 目录变化回调
    init(debounceInterval: UInt64 = 300_000_000, onChange: @escaping @Sendable (URL) -> Void) {
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        // 清理所有监控资源
        for (_, watch) in watches {
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)
        }
    }

    // MARK: - Public

    /// 开始监控指定目录
    func startWatching(url: URL) {
        queue.sync {
            let key = url.standardizedFileURL.path
            guard watches[key] == nil else { return }

            let fd = Darwin.open(key, O_EVTONLY)
            guard fd >= 0 else {
                if Self.verbose {
                    Self.logger.warning("\(Self.t)⚠️ 无法打开文件描述符监控目录：\(key)")
                }
                return
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .extend],
                queue: .global(qos: .utility)
            )

            let capturedOnChange = self.onChange
            let capturedURL = url
            source.setEventHandler {
                DispatchQueue.main.async {
                    capturedOnChange(capturedURL)
                }
            }

            source.resume()
            watches[key] = Watch(fileDescriptor: fd, source: source)

            if Self.verbose {
                Self.logger.info("\(Self.t)👁️ 开始监控目录：\(url.lastPathComponent)")
            }
        }
    }

    /// 停止监控指定目录
    func stopWatching(url: URL) {
        queue.sync {
            let key = url.standardizedFileURL.path
            guard let watch = watches.removeValue(forKey: key) else { return }
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)
            pendingRefreshes[key]?.cancel()
            pendingRefreshes.removeValue(forKey: key)

            if Self.verbose {
                Self.logger.info("\(Self.t)🛑 停止监控目录：\(url.lastPathComponent)")
            }
        }
    }

    /// 停止所有监控
    func stopAll() {
        queue.sync {
            for (_, watch) in watches {
                watch.source.cancel()
                Darwin.close(watch.fileDescriptor)
            }
            watches.removeAll()
            for (_, task) in pendingRefreshes {
                task.cancel()
            }
            pendingRefreshes.removeAll()

            if Self.verbose {
                Self.logger.info("\(Self.t)🛑 已停止所有目录监控")
            }
        }
    }

    /// 更新监控列表
    ///
    /// 根据传入的目录 URL 集合，添加新的监控、移除不再需要的监控。
    /// - Parameters:
    ///   - directoryURLs: 需要监控的目录 URL 集合
    func updateWatchedDirectories(_ directoryURLs: Set<URL>) {
        queue.sync {
            let desiredPaths = Set(directoryURLs.map { $0.standardizedFileURL.path })
            let currentPaths = Set(watches.keys)

            // 移除不再需要的监控
            for path in currentPaths where !desiredPaths.contains(path) {
                if let watch = watches.removeValue(forKey: path) {
                    watch.source.cancel()
                    Darwin.close(watch.fileDescriptor)
                }
                pendingRefreshes[path]?.cancel()
                pendingRefreshes.removeValue(forKey: path)
            }

            // 添加新的监控
            for path in desiredPaths {
                guard watches[path] == nil else { continue }
                let url = URL(fileURLWithPath: path)

                let fd = Darwin.open(path, O_EVTONLY)
                guard fd >= 0 else { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .delete, .rename, .extend],
                    queue: .global(qos: .utility)
                )

                let capturedOnChange = self.onChange
                source.setEventHandler {
                    DispatchQueue.main.async {
                        capturedOnChange(url)
                    }
                }

                source.resume()
                watches[path] = Watch(fileDescriptor: fd, source: source)
            }
        }
    }

    // MARK: - Debounce

    /// 带防抖的刷新通知
    ///
    /// 同一个目录在短时间内可能触发多次文件系统事件，
    /// 使用防抖机制合并为一次回调。
    /// - Parameter url: 发生变化的目录 URL
    func notifyChanged(url: URL) {
        let key = url.standardizedFileURL.path
        pendingRefreshes[key]?.cancel()

        pendingRefreshes[key] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceInterval)
            onChange(url)
        }
    }

    // MARK: - Query

    /// 当前正在监控的目录数量
    var watchCount: Int {
        queue.sync { watches.count }
    }
}
