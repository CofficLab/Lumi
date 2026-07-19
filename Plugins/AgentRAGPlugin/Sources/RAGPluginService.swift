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

    static func configure(kernel: LumiKernel) {
        let directoryProvider: @Sendable () -> URL = { [weak kernel] in
            guard let kernel, let storage = kernel.storage else {
                return RAGPluginRuntime.databaseDirectoryProvider()
            }
            return storage.pluginDataDirectory(for: "RAG")
        }

        service = RAGService(
            databaseDirectoryProvider: directoryProvider,
            onProgress: { event in
                NotificationCenter.postRAGIndexProgress(event)
            }
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

extension RAGPlugin {
    @MainActor
    static func getService() -> RAGService {
        RAGPluginService.getService()
    }
}
