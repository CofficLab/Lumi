import Foundation
import os

@MainActor
enum RAGPluginService {
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
        Task {
            try? await service.initialize()
        }
    }
}

extension RAGPlugin {
    @MainActor
    static func getService() -> RAGService {
        RAGPluginService.getService()
    }
}
