import Foundation
import AppKit
import ProviderIdleTime
import ProviderProject
import LumiLoggingKit
import os

/// Owns low-priority indexing of known inactive projects.
///
/// The scheduler deliberately has one worker. `RAGSQLiteStore` owns one SQLite
/// connection, so serializing projects here avoids write races and keeps the
/// foreground query path predictable.
@MainActor
public final class RAGIndexScheduler: SuperLog {
    nonisolated public static let emoji = "📚"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project.rag.scheduler")

    private let projects: any ProjectProviding
    private let idleTime: any IdleTimeProviding
    private let service: RAGService
    private let configuration: RAGIndexSchedulingConfiguration
    private let pathProbe: any RAGProjectPathProbing
    private var retryStates: [String: RAGIndexRetryState] = [:]
    private let retryStateURL: URL
    private var nextEligibleAt = Date.distantPast
    private var interruptionObserver: RAGIndexInterruptionObserver?

    /// 上一次候选扫描的结果与时间。成功切片后复用它，避免每片都重扫全部项目路径。
    private var candidateCache: [RAGIndexCandidate] = []
    private var candidateCacheAt = Date.distantPast

    /// 调度器状态落盘队列：编码与写文件都不在主线程。
    private nonisolated let stateQueue = DispatchQueue(
        label: "com.coffic.lumi.rag.scheduler.state",
        qos: .utility
    )

    public init(
        projects: any ProjectProviding,
        idleTime: any IdleTimeProviding,
        service: RAGService,
        stateDirectory: URL,
        pathProbe: any RAGProjectPathProbing = RAGDefaultProjectPathProbe()
    ) {
        self.projects = projects
        self.idleTime = idleTime
        self.service = service
        self.configuration = .init()
        self.pathProbe = pathProbe
        self.retryStateURL = stateDirectory.appendingPathComponent("index-scheduler-state.json")
        self.retryStates = Self.loadRetryStates(from: retryStateURL)
        interruptionObserver = RAGIndexInterruptionObserver { [weak self] in
            await self?.interruptForForegroundActivity()
        }
    }

    public func run() async {
        defer {
            interruptionObserver?.cancel()
            interruptionObserver = nil
        }
        while !Task.isCancelled {
            guard Date() >= nextEligibleAt else {
                await sleep(max(nextEligibleAt.timeIntervalSinceNow, configuration.schedulerPollInterval))
                continue
            }
            guard !(await service.isIndexingPaused()) else {
                await sleep(configuration.schedulerPollInterval)
                continue
            }

            let prediction = await idleTime.idlePrediction(for: configuration.idlePredictionDuration)
            guard prediction.isLikelyIdle else {
                await sleep(configuration.schedulerPollInterval)
                continue
            }

            let candidates = await candidatesForNextSlice()
            guard let candidate = RAGIndexCandidateSelector.select(
                candidates: candidates,
                currentProjectPath: currentProjectPath,
                retryStates: retryStates,
                now: Date()
            ) else {
                await sleep(configuration.schedulerPollInterval)
                continue
            }

            do {
                if Self.verbose {
                    Self.logger.info("\(Self.t)idle scheduler indexing project=\(candidate.projectPath)")
                }
                // 在派发切片前捕获令牌，前台中断后这个切片不会再重启后台索引。
                let token = await service.backgroundIndexingToken()
                let outcome = try await runWorkSlice(for: candidate.projectPath, token: token)
                if outcome.confirmsProgress {
                    retryStates[candidate.projectPath, default: .init()].recordSuccess()
                    saveRetryStates()
                    // 消费掉刚服务过的候选：下一片直接复用剩余候选，
                    // 缓存空了才重扫，避免 P 个项目各成功一片就触发 P 次全量探测。
                    consumeCandidate(candidate.projectPath)
                } else {
                    // 节流/暂停跳过不代表成功：保留失败退避，并等待一个轮询
                    // 间隔，避免同一候选在节流窗口内无 sleep 地反复空转（回归 #1116）。
                    nextEligibleAt = Date().addingTimeInterval(configuration.schedulerPollInterval)
                }
            } catch is RAGIndexSliceExpired {
                // A slice ending is expected; incremental file state lets the
                // next idle window resume without losing completed files.
            } catch is CancellationError {
                if Task.isCancelled {
                    return
                }
                // Foreground activity cancelled the current slice. Keep the
                // scheduler alive and wait for the next admission window.
                await sleep(configuration.schedulerPollInterval)
            } catch {
                var state = retryStates[candidate.projectPath, default: .init()]
                state.recordFailure(at: Date(), configuration: configuration)
                retryStates[candidate.projectPath] = state
                saveRetryStates()
                Self.logger.error("\(Self.t)idle scheduler failed project=\(candidate.projectPath) failures=\(state.failureCount) error=\(error.localizedDescription)")
            }
        }
    }

    private var currentProjectPath: String? {
        projects.currentProject?.path
    }

    /// 取下一片用的候选：缓存仍新鲜就直接复用，不重扫路径。
    func candidatesForNextSlice() async -> [RAGIndexCandidate] {
        if !candidateCache.isEmpty,
           Date().timeIntervalSince(candidateCacheAt) < configuration.candidateRefreshInterval {
            return candidateCache
        }
        let scanned = await makeCandidates()
        candidateCache = scanned
        candidateCacheAt = Date()
        return scanned
    }

    /// 一轮切片成功后消费掉该候选；缓存空了才会在下一轮重新扫描。
    func consumeCandidate(_ projectPath: String) {
        candidateCache.removeAll { $0.projectPath == projectPath }
    }

    func makeCandidates() async -> [RAGIndexCandidate] {
        // 主线程只捕获不可变快照：规范化后的路径列表 + 当前项目。
        // 当前项目在探测**之前**就排除，省掉一次必然被丢弃的文件系统调用。
        let capturedCurrentPath = RAGPathUtils.normalizeProjectPath(currentProjectPath ?? "")
        let paths = projects.projects
            .map { RAGPathUtils.normalizeProjectPath($0.path) }
            .filter { !$0.isEmpty && $0 != capturedCurrentPath }
        guard !paths.isEmpty else { return [] }

        // 路径探测是同步文件系统调用，外接/网络卷可能阻塞很久，放到后台 worker。
        let probe = pathProbe
        let worker = Task.detached(priority: .utility) { () -> [String] in
            var existing: [String] = []
            existing.reserveCapacity(paths.count)
            for path in paths {
                if Task.isCancelled { return [] }
                if probe.isDirectory(atPath: path) {
                    existing.append(path)
                }
            }
            return existing
        }
        // detached 任务不继承父任务取消，必须显式转发。
        let existing = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
        guard !Task.isCancelled else { return [] }
        // 身份校验：探测期间用户可能已切换项目，旧扫描结果整份丢弃。
        guard capturedCurrentPath == RAGPathUtils.normalizeProjectPath(currentProjectPath ?? "") else {
            return []
        }

        var candidates: [RAGIndexCandidate] = []
        candidates.reserveCapacity(existing.count)
        for path in existing {
            let status = try? await service.getIndexStatus(projectPath: path)
            let needsIndex = (try? await service.checkNeedsIndex(projectPath: path)) ?? true
            guard needsIndex else { continue }
            candidates.append(
                RAGIndexCandidate(
                    projectPath: path,
                    lastIndexedAt: status?.lastIndexedAt,
                    needsIndex: needsIndex
                )
            )
        }

        return candidates
    }

    private func runWorkSlice(
        for projectPath: String,
        token: RAGBackgroundIndexToken
    ) async throws -> RAGIndexEnsureOutcome {
        try await withThrowingTaskGroup(of: RAGIndexEnsureOutcome.self) { group in
            group.addTask { [service] in
                try await service.ensureIndexed(
                    projectPath: projectPath,
                    background: true,
                    token: token
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5 * 60))
                throw RAGIndexSliceExpired()
            }

            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    private func saveRetryStates() {
        // 主线程只交出不可变快照，建目录/编码/写文件都在串行队列上，
        // 顺序与调用顺序一致。
        let snapshot = retryStates
        let url = retryStateURL
        stateQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                Self.logger.error("\(Self.t)failed to persist scheduler state error=\(error.localizedDescription)")
            }
        }
    }

    private static func loadRetryStates(from url: URL) -> [String: RAGIndexRetryState] {
        guard let data = try? Data(contentsOf: url),
              let states = try? JSONDecoder().decode([String: RAGIndexRetryState].self, from: data) else {
            return [:]
        }
        return states
    }

    private func sleep(_ interval: TimeInterval) async {
        do {
            try await Task.sleep(for: .seconds(interval))
        } catch {
            // Cancellation is observed by the loop on the next iteration.
        }
    }

    private func interruptForForegroundActivity() async {
        nextEligibleAt = Date().addingTimeInterval(configuration.schedulerPollInterval)
        // 前台活动后项目列表可能已变，下一个空闲窗口重新扫描。
        candidateCache = []
        await service.cancelBackgroundIndexing()
    }
}
