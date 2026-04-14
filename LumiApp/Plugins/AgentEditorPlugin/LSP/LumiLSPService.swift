import Foundation
import SwiftUI
import LanguageClient
import LanguageServerProtocol
import os
import Combine

/// LSP 服务管理器
/// 基于 LanguageClient + LanguageServerProtocol + JSONRPC
/// 完全参考 CodeEdit 的 LSPService 架构
@MainActor
final class LumiLSPService: ObservableObject {
    
    static let shared = LumiLSPService()
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.service")
    
    // MARK: - Published State
    
    @Published var currentDiagnostics: [Diagnostic] = []
    @Published var isAvailable: Bool = false
    @Published var activeLanguageId: String?
    @Published var isInitializing: Bool = false
    
    // MARK: - Properties
    
    private var server: LumiLanguageServer?
    private var currentURI: String?
    private var currentVersion: Int = 0
    private var projectRootPath: String?
    
    private var changeDebounceTimer: Timer?
    private var pendingText: String?
    
    var onCompletion: (([CompletionItem]) -> Void)?
    var onHover: ((String?) -> Void)?
    
    init() {
        checkAvailability()
    }
    
    // MARK: - Availability
    
    func checkAvailability() {
        let swiftAvailable = LumiLSPConfig.findServer(for: "swift") != nil
        isAvailable = swiftAvailable
        logger.info("LSP availability: Swift = \(swiftAvailable ? "yes" : "no")")
    }
    
    // MARK: - Server Management
    
    func startServer(for languageId: String, projectPath: String) async {
        if let existing = server {
            logger.info("Stopping existing server")
            try? await existing.shutdown()
            server = nil
        }
        
        guard let config = LumiLSPConfig.defaultConfig(for: languageId) else {
            logger.warning("No server config for \(languageId)")
            return
        }
        
        logger.info("Starting server for \(languageId) at \(config.execPath)")
        isInitializing = true
        activeLanguageId = languageId
        projectRootPath = projectPath
        
        do {
            let newServer = try await LumiLanguageServer.create(
                languageId: languageId,
                config: config,
                workspacePath: projectPath
            )
            
            server = newServer
            isInitializing = false
            logger.info("Server initialized for \(languageId)")
        } catch {
            logger.error("Failed to start server: \(error.localizedDescription)")
            isInitializing = false
            activeLanguageId = nil
        }
    }
    
    // MARK: - Document Lifecycle
    
    func openDocument(uri: String, languageId: String, text: String) async {
        if server == nil || activeLanguageId != languageId {
            if let root = projectRootPath {
                await startServer(for: languageId, projectPath: root)
            } else {
                logger.warning("No project root")
                return
            }
        }
        
        guard let server else { return }
        
        currentURI = uri
        currentVersion = 0
        
        do {
            try await server.openDocument(uri: uri, languageId: languageId, text: text)
        } catch {
            logger.error("Failed to open document: \(error)")
        }
    }
    
    func closeDocument(uri: String) {
        guard let server else { return }
        Task {
            do {
                try await server.closeDocument(uri: uri)
                if currentURI == uri {
                    currentURI = nil
                    currentDiagnostics = []
                }
            } catch {
                logger.error("Failed to close document: \(error)")
            }
        }
    }
    
    func documentDidChange(uri: String, text: String) {
        currentVersion += 1
        pendingText = text
        
        changeDebounceTimer?.invalidate()
        changeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.flushChange(uri: uri)
            }
        }
    }
    
    private func flushChange(uri: String) async {
        guard let server, let text = pendingText else { return }
        do {
            try await server.documentDidChange(uri: uri, text: text)
            pendingText = nil
        } catch {
            logger.error("Failed to send change: \(error)")
        }
    }
    
    // MARK: - LSP Features
    
    func requestCompletion(uri: String, line: Int, character: Int) async {
        guard let server else { return }
        do {
            let response: CompletionResponse = try await server.completion(uri: uri, line: line, character: character)
            let items = parseCompletionItems(response)
            await MainActor.run { onCompletion?(items) }
        } catch {
            logger.error("Completion failed: \(error)")
        }
    }
    
    func requestHover(uri: String, line: Int, character: Int) async {
        guard let server else { return }
        do {
            let hover = try await server.hover(uri: uri, line: line, character: character)
            let content = parseHoverContent(hover)
            await MainActor.run { onHover?(content) }
        } catch {
            logger.error("Hover failed: \(error)")
        }
    }
    
    func requestDefinition(uri: String, line: Int, character: Int) async -> Location? {
        guard let server else { return nil }
        do {
            let response: DefinitionResponse = try await server.definition(uri: uri, line: line, character: character)
            return parseDefinitionLocation(response)
        } catch {
            logger.error("Definition failed: \(error)")
            return nil
        }
    }
    
    func requestReferences(uri: String, line: Int, character: Int) async -> [Location] {
        guard let server else { return [] }
        do {
            return try await server.references(uri: uri, line: line, character: character)
        } catch {
            logger.error("References failed: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup
    
    func stopAll() {
        if let server {
            Task { try? await server.shutdown() }
        }
        server = nil
        currentURI = nil
        currentDiagnostics = []
        activeLanguageId = nil
    }
    
    // MARK: - Parsing
    
    /// CompletionResponse = TwoTypeOption<[CompletionItem], CompletionList>?
    private func parseCompletionItems(_ response: CompletionResponse) -> [CompletionItem] {
        guard let response else { return [] }
        switch response {
        case .optionA(let array):
            return array
        case .optionB(let list):
            return list.items
        }
    }
    
    /// HoverResponse = Hover?
    /// Hover.contents = ThreeTypeOption<MarkedString, [MarkedString], MarkupContent>
    /// MarkedString = TwoTypeOption<String, LanguageStringPair>
    private func parseHoverContent(_ hover: Hover?) -> String? {
        guard let hover else { return nil }
        
        switch hover.contents {
        case .optionC(let markup):
            return markup.value
        case .optionA(let marked):
            switch marked {
            case .optionA(let str):
                return str
            case .optionB(let lsp):
                return "```\n\(lsp.value)\n```"
            }
        case .optionB(let array):
            return array.compactMap { m -> String? in
                switch m {
                case .optionA(let str): return str
                case .optionB(let lsp): return "```\n\(lsp.value)\n```"
                }
            }.joined(separator: "\n---\n")
        }
    }
    
    /// DefinitionResponse = ThreeTypeOption<Location, [Location], [LocationLink]>?
    private func parseDefinitionLocation(_ response: DefinitionResponse) -> Location? {
        guard let response else { return nil }
        switch response {
        case .optionA(let location):
            return location
        case .optionB(let locations):
            return locations.first
        case .optionC(let links):
            guard let link = links.first else { return nil }
            return Location(uri: link.targetUri, range: link.targetSelectionRange)
        }
    }
}
