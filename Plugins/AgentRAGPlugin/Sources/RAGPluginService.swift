import Foundation
import os

@MainActor
enum RAGPluginService {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag")

    private(set) static var service: RAGService = RAGService(
        databaseDirectoryProvider: {
            RAGPluginRuntime.databaseDirectoryProvider()
        },
        onProgress: { event in
            NotificationCenter.postRAGIndexProgress(event)
        }
    )

    static func getService() -> RAGService {
        service
    }

    static func initializeIfNeeded() {
        guard !service.isInitialized else { return }
        // 异步 fire-and-forget：受限于 agentTools 的同步签名，初始化错误无法经
        // throws 上抛到 UI。这里至少捕获并记录日志，避免错误被完全静默吞掉。
        Task {
            do {
                try await service.initialize()
            } catch {
                logger.error("RAG 服务初始化失败：\(error.localizedDescription)")
            }
        }
    }
}

extension RAGPlugin {
    @MainActor
    static func getService() -> RAGService {
        RAGPluginService.getService()
    }
}
