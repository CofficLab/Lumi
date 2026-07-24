import Foundation
import LumiKernel
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

    static func configure(kernel: LumiKernel) {
        // Resolve the directory eagerly on the main actor so the Sendable
        // provider closure does not need to touch @MainActor-isolated state.
        let resolvedDirectory: URL = {
            guard let storage = kernel.storage else {
                return RAGPluginRuntime.databaseDirectoryProvider()
            }
            return storage.pluginDataDirectory(for: "RAG")
        }()

        let directoryProvider: @Sendable () -> URL = { resolvedDirectory }

        let onProgress: @Sendable (RAGIndexProgressEvent) -> Void = { event in
            NotificationCenter.postRAGIndexProgress(event)
        }

        service = RAGService(
            databaseDirectoryProvider: directoryProvider,
            onProgress: onProgress
        )
    }

    static func initializeIfNeeded() {
        guard !service.isInitialized else { return }
        Task {
            do {
                try await service.initialize()
            } catch {
                logger.error("RAG 服务初始化失败：\(error.localizedDescription)")
            }
        }
    }
}

extension ProjectRAGPlugin {
    @MainActor
    static func getService() -> RAGService {
        RAGPluginService.getService()
    }
}
