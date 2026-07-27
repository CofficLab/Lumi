import Foundation
import LumiKernel
import SuperLogKit
import os

@MainActor
enum RAGPluginService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project.rag")
    nonisolated static let emoji = ProjectRAGPlugin.emoji
    nonisolated static let verbose = true

    private(set) static var service: RAGService = RAGService(
        databaseDirectoryProvider: {
            RAGPluginRuntime.databaseDirectoryProvider()
        },
        onProgress: { event in
            NotificationCenter.postRAGIndexProgress(event)
        }
    )

    static func getService() -> RAGService {
        if Self.verbose {
            Self.logger.info("\(Self.t)getService initialized=\(service.isInitialized)")
        }
        return service
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

        if Self.verbose {
            let hasStorage = kernel.storage != nil
            Self.logger.info("\(Self.t)configure hasStorage=\(hasStorage) dbDir=\(resolvedDirectory.path)")
        }

        let directoryProvider: @Sendable () -> URL = { resolvedDirectory }

        let onProgress: @Sendable (RAGIndexProgressEvent) -> Void = { event in
            NotificationCenter.postRAGIndexProgress(event)
        }

        service = RAGService(
            databaseDirectoryProvider: directoryProvider,
            onProgress: onProgress
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)configure completed initialized=\(service.isInitialized)")
        }
    }

}

extension ProjectRAGPlugin {
    @MainActor
    static func getService() -> RAGService {
        RAGPluginService.getService()
    }
}
