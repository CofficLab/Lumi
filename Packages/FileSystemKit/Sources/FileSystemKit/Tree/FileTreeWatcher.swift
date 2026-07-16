import Foundation
import os
import SuperLogKit

/// 文件树目录变化监听器
///
/// 使用 DispatchSource 监控指定目录的文件系统变化，
/// 检测到变化后通过回调通知上层。
///
/// 设计原则：
/// - 仅监听指定的目录集合（懒监听，避免不必要的系统开销）
/// - 文件系统事件立即转发，由上层合并高频刷新
/// - 所有公开方法通过串行队列保护内部状态，线程安全
public final class FileTreeWatcher: SuperLog, @unchecked Sendable {

    // MARK: - Types

    /// 目录变化回调，参数为发生变化的目录 URL
    public typealias OnDirectoryChanged = @Sendable (URL) -> Void

    /// 单个目录的监控状态
    private struct Watch {
        let fileDescriptor: Int32
        let source: DispatchSourceProtocol
    }

    // MARK: - Properties

    /// 日志记录器
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "file-tree.watcher")

    /// 当前活跃的监控，key 为标准化路径
    private var watches: [String: Watch] = [:]

    /// 目录变化回调
    private let onChange: OnDirectoryChanged

    /// 操作队列，确保 watches 字典的读写安全
    private let queue = DispatchQueue(label: "FileTreeWatcher.queue", qos: .utility)

    /// 是否启用日志
    public var verbose: Bool = false

    // MARK: - Init

    /// 初始化监听器
    /// - Parameter onChange: 目录变化回调
    public init(onChange: @escaping @Sendable (URL) -> Void) {
        self.onChange = onChange
    }

    deinit {
        for (_, watch) in watches {
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)
        }
    }

    // MARK: - Public

    /// 开始监控指定目录
    /// - Parameter url: 要监控的目录 URL
    public func startWatching(url: URL) {
        queue.sync {
            let key = url.standardizedFileURL.path
            guard watches[key] == nil else { return }

            let fd = Darwin.open(key, O_EVTONLY)
            guard fd >= 0 else {
                if verbose {
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

            if verbose {
                Self.logger.info("\(Self.t)👁️ 开始监控目录：\(url.lastPathComponent)")
            }
        }
    }

    /// 停止监控指定目录
    /// - Parameter url: 要停止监控的目录 URL
    public func stopWatching(url: URL) {
        queue.sync {
            let key = url.standardizedFileURL.path
            guard let watch = watches.removeValue(forKey: key) else { return }
            watch.source.cancel()
            Darwin.close(watch.fileDescriptor)

            if verbose {
                Self.logger.info("\(Self.t)🛑 停止监控目录：\(url.lastPathComponent)")
            }
        }
    }

    /// 停止所有监控
    public func stopAll() {
        queue.sync {
            for (_, watch) in watches {
                watch.source.cancel()
                Darwin.close(watch.fileDescriptor)
            }
            watches.removeAll()

            if verbose {
                Self.logger.info("\(Self.t)🛑 已停止所有目录监控")
            }
        }
    }

    /// 更新监控列表
    ///
    /// 根据传入的目录 URL 集合，添加新的监控、移除不再需要的监控。
    /// - Parameter directoryURLs: 需要监控的目录 URL 集合
    public func updateWatchedDirectories(_ directoryURLs: Set<URL>) {
        queue.sync {
            let desiredPaths = Set(directoryURLs.map { $0.standardizedFileURL.path })
            let currentPaths = Set(watches.keys)

            // 移除不再需要的监控
            for path in currentPaths where !desiredPaths.contains(path) {
                if let watch = watches.removeValue(forKey: path) {
                    watch.source.cancel()
                    Darwin.close(watch.fileDescriptor)
                }
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

    // MARK: - Query

    /// 当前正在监控的目录数量
    public var watchCount: Int {
        queue.sync { watches.count }
    }
}
