import MagicKit
import SwiftUI
import os

/// RAG 插件
actor RAGPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id = "rag"
    static let navigationId: String = "rag_settings"
    static let displayName = String(localized: "RAG")
    static let description = String(localized: "Retrieval-Augmented Generation", table: "RAG")
    static let iconName = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = false
    static var order: Int { 200 }

    static let logger = Logger(subsystem: "com.coffic.lumi", category: "RAG")

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RAGPlugin()

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        if Self.verbose {
            Self.logger.info("\(Self.t)🦞 RAG 中间件已启用")
        }
        return [AnySendMiddleware(RAGSendMiddleware())]
    }
}
