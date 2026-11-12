import CoreServices
import Foundation
import LumiLoggingKit
import os

/// Task 3.2：监听当前项目目录的 FSEvents，debounce 合并后触发增量索引。
///
/// 身份校验（AGENTS.md）：回调携带发起时的 projectPath，触发前与当前项目
/// 比对，不一致直接丢弃；项目切换由外部 stop/start 完成，旧流与未决
/// debounce 一并取消。索引暂停时不触发；300s stale 兜底仍由 RAGService 保留。
public final class RAGProjectWatcher: SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "👁"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag.watcher")

    private let debounceInterval: TimeInterval
    private let streamLatency: TimeInterval
    private let isPaused: @Sendable () async -> Bool
    private let currentProjectPath: @Sendable () async -> String?
    private let trigger: @Sendable (String) async -> Void

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.coffic.lumi.rag.watcher")
    private var stream: FSEventStreamRef?
    private var watchedPath: String?
    private var pendingWork: DispatchWorkItem?

    public init(
        debounceInterval: TimeInterval = 2,
        streamLatency: TimeInterval = 1,
        isPaused: @escaping @Sendable () async -> Bool,
        currentProjectPath: @escaping @Sendable () async -> String?,
        trigger: @escaping @Sendable (String) async -> Void
    ) {
        self.debounceInterval = debounceInterval
        self.streamLatency = streamLatency
        self.isPaused = isPaused
        self.currentProjectPath = currentProjectPath
        self.trigger = trigger
    }

    deinit {
        stop()
    }

    /// 开始监听新项目：先停旧流并取消未决 debounce，再起新流。
    public func start(projectPath: String) {
        lock.lock()
        defer { lock.unlock() }
        stopLocked()
        watchedPath = projectPath

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, count, paths, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<RAGProjectWatcher>.fromOpaque(info).takeUnretainedValue()
                // 实测（macOS 27）：dispatch queue 回调的 eventPaths 是 C 字符串
                // 数组；按 CFArray 解引用会段错误。
                let cPaths = paths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
                var pathList: [String] = []
                pathList.reserveCapacity(count)
                for index in 0..<count {
                    if let pointer = cPaths[index] {
                        pathList.append(String(cString: pointer))
                    }
                }
                watcher.handleEvent(paths: pathList)
            },
            &context,
            [projectPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            streamLatency,
            flags
        ) else {
            watchedPath = nil
            return
        }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    /// 停止监听并释放流（onShutdown 必须调用，不得泄漏）。
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopLocked()
    }

    private func stopLocked() {
        pendingWork?.cancel()
        pendingWork = nil
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        watchedPath = nil
    }

    /// FSEvents 回调与单测注入入口：只投递路径集合并重置 debounce，不直接索引。
    func handleEvent(paths: [String]) {
        lock.lock()
        guard let projectPath = watchedPath else {
            lock.unlock()
            return
        }
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { await self.fire(projectPath: projectPath) }
        }
        pendingWork = work
        lock.unlock()

        if Self.verbose {
            Self.logger.info("\(Self.t)文件事件 \(paths.count) 条，\(self.debounceInterval)s 后触发增量索引")
        }
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func fire(projectPath: String) async {
        guard let current = await currentProjectPath(), current == projectPath else {
            if Self.verbose {
                Self.logger.info("\(Self.t)丢弃旧项目事件: \(projectPath)")
            }
            return
        }
        guard await !isPaused() else { return }
        await trigger(projectPath)
    }
}