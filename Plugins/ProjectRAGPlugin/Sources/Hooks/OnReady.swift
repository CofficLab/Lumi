import Foundation
import LumiKernel
import SuperLogKit
import os

/// Project RAG 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的运行时注册与服务初始化。
@MainActor
public struct ProjectRAGOnReadyHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project.rag")
    nonisolated public static let emoji = ProjectRAGPlugin.emoji
    nonisolated static let verbose = true

    public init() {}

    /// 执行 onReady。
    public func execute(_ kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)onReady")
        }

        // RAG capabilities are provided through RAGPluginService singleton.
        RAGPluginRuntime.kernel = kernel
        await RAGPluginService.configure(kernel: kernel)
        bootstrapRuntime(kernel: kernel)
        startBackgroundIndexing(kernel: kernel)

        if Self.verbose {
            Self.logger.info("\(Self.t)onReady completed")
        }
    }

    private func bootstrapRuntime(kernel: LumiKernel) {
        let ragDirectory = kernel.storage?.pluginDataDirectory(for: "RAG")
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }

    func startBackgroundIndexing(kernel: LumiKernel) {
        let service = RAGPluginService.getService()
        if Self.verbose {
            Self.logger.info("\(Self.t)background indexing scheduled")
        }

        let task = Task { @MainActor in
            do {
                if Self.verbose {
                    Self.logger.info("\(Self.t)background service initialize begin")
                }
                try await service.initialize()
                if Self.verbose {
                    Self.logger.info("\(Self.t)background service initialize completed initialized=\(service.isInitialized)")
                }

                guard let currentPath = await waitForCurrentProjectPath(kernel: kernel) else {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)background indexing skipped: no current project after retries")
                    }
                    return
                }

                guard !Task.isCancelled else {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)background indexing cancelled")
                    }
                    return
                }

                if Self.verbose {
                    Self.logger.info("\(Self.t)background ensure index current project=\(currentPath)")
                }
                await service.ensureIndexedBackground(projectPath: currentPath)
            } catch {
                Self.logger.error("\(Self.t)background service initialize failed: \(error.localizedDescription)")
            }
        }
        RAGPluginService.replaceLifecycleTask(task)
    }

    public func setIndexingPaused(_ paused: Bool, kernel: LumiKernel) async {
        await RAGPluginService.setIndexingPaused(paused)

        guard !paused else { return }
        startBackgroundIndexing(kernel: kernel)
    }

    private func waitForCurrentProjectPath(kernel: LumiKernel) async -> String? {
        for attempt in 1...10 {
            let currentPath = kernel.project?.currentProject?.path ?? ""
            let candidatePath = Self.uniqueExistingProjectPaths([currentPath]).first

            if let candidatePath {
                if Self.verbose {
                    Self.logger.info("\(Self.t)background current project ready attempt=\(attempt) path=\(candidatePath)")
                }
                return candidatePath
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)background current project unavailable attempt=\(attempt)")
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        return nil
    }

    nonisolated private static func uniqueExistingProjectPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawPath in paths {
            let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let normalized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
            guard !seen.contains(normalized) else { continue }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)background indexing skip missing directory=\(normalized)")
                }
                continue
            }

            seen.insert(normalized)
            result.append(normalized)
        }

        return result
    }
}
