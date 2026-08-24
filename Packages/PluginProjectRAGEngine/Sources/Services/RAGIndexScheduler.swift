import Foundation
import AppKit
import ProviderIdleTime
import ProviderProject
import SuperLogKit
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
    private var retryStates: [String: RAGIndexRetryState] = [:]
    private let retryStateURL: URL
    private var nextEligibleAt = Date.distantPast
    private var observers: [NSObjectProtocol] = []

    public init(
        projects: any ProjectProviding,
        idleTime: any IdleTimeProviding,
        service: RAGService,
        stateDirectory: URL
    ) {
        self.projects = projects
        self.idleTime = idleTime
        self.service = service
        self.configuration = .init()
        self.retryStateURL = stateDirectory.appendingPathComponent("index-scheduler-state.json")
        self.retryStates = Self.loadRetryStates(from: retryStateURL)
        installInterruptionObservers()
    }

    public func run() async {
        defer { removeInterruptionObservers() }
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

            let candidates = await makeCandidates()
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
                try await runWorkSlice(for: candidate.projectPath)
                retryStates[candidate.projectPath, default: .init()].recordSuccess()
                saveRetryStates()
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

    private func makeCandidates() async -> [RAGIndexCandidate] {
        let projects = projects.projects
        var candidates: [RAGIndexCandidate] = []
        candidates.reserveCapacity(projects.count)

        for project in projects {
            let path = RAGPathUtils.normalizeProjectPath(project.path)
            guard !path.isEmpty, FileManager.default.isDirectory(atPath: path) else { continue }
            guard path != RAGPathUtils.normalizeProjectPath(currentProjectPath ?? "") else { continue }

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

    private func runWorkSlice(for projectPath: String) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [service] in
                try await service.ensureIndexed(projectPath: projectPath, background: true)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5 * 60))
                throw RAGIndexSliceExpired()
            }

            defer { group.cancelAll() }
            try await group.next()!
        }
    }

    private func saveRetryStates() {
        do {
            try FileManager.default.createDirectory(
                at: retryStateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(retryStates)
            try data.write(to: retryStateURL, options: .atomic)
        } catch {
            Self.logger.error("\(Self.t)failed to persist scheduler state error=\(error.localizedDescription)")
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

    private func installInterruptionObservers() {
        let names: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.interruptForForegroundActivity()
                }
            }
        }
    }

    private func removeInterruptionObservers() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func interruptForForegroundActivity() async {
        nextEligibleAt = Date().addingTimeInterval(configuration.schedulerPollInterval)
        await service.cancelBackgroundIndexing()
    }
}

private extension FileManager {
    func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
