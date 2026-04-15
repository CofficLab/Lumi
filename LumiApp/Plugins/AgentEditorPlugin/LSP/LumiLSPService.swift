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
    private var pendingChanges: [LumiLanguageServer.DocumentChange] = []
    private var latestDocumentSnapshot: String?
    
    var onHover: ((String?) -> Void)?
    
    init() {
        checkAvailability()
    }
    
    // MARK: - Availability
    
    func checkAvailability(for languageId: String? = nil) {
        if let languageId {
            let available = LumiLSPConfig.findServer(for: languageId) != nil
            isAvailable = available
            logger.info("LSP availability: \(languageId) = \(available ? "yes" : "no")")
            return
        }

        let available = LumiLSPConfig.supportedLanguageIds.contains {
            LumiLSPConfig.findServer(for: $0) != nil
        }
        isAvailable = available
        logger.info("LSP availability(any) = \(available ? "yes" : "no")")
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
            newServer.onPublishDiagnostics = { [weak self] params in
                Task { @MainActor [weak self] in
                    self?.handlePublishDiagnostics(params)
                }
            }
            
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
    
    func setProjectRootPath(_ projectPath: String?) {
        projectRootPath = projectPath
    }
    
    func openDocument(uri: String, languageId: String, text: String) async {
        checkAvailability(for: languageId)

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
        latestDocumentSnapshot = text
        pendingChanges.removeAll()
        currentDiagnostics = []
        
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
                    latestDocumentSnapshot = nil
                    pendingChanges.removeAll()
                }
            } catch {
                logger.error("Failed to close document: \(error)")
            }
        }
    }
    
    func updateDocumentSnapshot(uri: String, text: String) {
        guard uri == currentURI else { return }
        latestDocumentSnapshot = text
    }
    
    func documentDidChange(uri: String, range: LSPRange, text: String) {
        guard uri == currentURI else { return }
        currentVersion += 1
        pendingChanges.append(.init(range: range, text: text))
        
        changeDebounceTimer?.invalidate()
        changeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.flushChange(uri: uri)
            }
        }
    }
    
    private func flushChange(uri: String) async {
        guard let server, !pendingChanges.isEmpty else { return }
        let changes = pendingChanges
        let snapshot = latestDocumentSnapshot
        do {
            try await server.documentDidChange(uri: uri, changes: changes, fullText: snapshot)
            pendingChanges.removeAll()
        } catch {
            logger.error("Failed to send change: \(error)")
        }
    }
    
    func replaceDocument(uri: String, text: String) {
        guard uri == currentURI else { return }
        latestDocumentSnapshot = text
        pendingChanges.removeAll()
        changeDebounceTimer?.invalidate()
        changeDebounceTimer = nil
        guard let server else { return }
        Task {
            do {
                try await server.documentDidChange(uri: uri, text: text)
            } catch {
                logger.error("Failed to replace document text: \(error)")
            }
        }
    }
    
    // MARK: - LSP Features
    
    func requestCompletion(uri: String, line: Int, character: Int) async -> [CompletionItem] {
        guard let server else { return [] }
        do {
            let response: CompletionResponse = try await server.completion(uri: uri, line: line, character: character)
            return parseCompletionItems(response)
        } catch {
            logger.error("Completion failed: \(error)")
            return []
        }
    }
    
    func requestHover(uri: String, line: Int, character: Int) async -> String? {
        guard let server else { return nil }
        do {
            let hover = try await server.hover(uri: uri, line: line, character: character)
            let content = parseHoverContent(hover)
            await MainActor.run { onHover?(content) }
            return content
        } catch {
            logger.error("Hover failed: \(error)")
            return nil
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

    func requestDocumentSymbols(uri: String) async -> [DocumentSymbol] {
        guard let server else { return [] }
        do {
            return try await server.documentSymbols(uri: uri)
        } catch {
            logger.error("Document symbols failed: \(error)")
            return []
        }
    }

    func requestRename(uri: String, line: Int, character: Int, newName: String) async -> WorkspaceEdit? {
        guard let server else { return nil }
        do {
            return try await server.rename(uri: uri, line: line, character: character, newName: newName)
        } catch {
            logger.error("Rename failed: \(error)")
            return nil
        }
    }

    func requestFormatting(uri: String, tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? {
        guard let server else { return nil }
        do {
            return try await server.formatting(uri: uri, tabSize: tabSize, insertSpaces: insertSpaces)
        } catch {
            logger.error("Formatting failed: \(error)")
            return nil
        }
    }
    
    func requestSignatureHelp(uri: String, line: Int, character: Int) async -> SignatureHelp? {
        guard let server else { return nil }
        guard server.capabilities.signatureHelpProvider != nil else { return nil }
        do {
            return try await server.signatureHelp(uri: uri, line: line, character: character)
        } catch {
            logger.error("Signature help failed: \(error)")
            return nil
        }
    }
    
    func requestInlayHint(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? {
        guard let server else { return nil }
        guard server.capabilities.inlayHintProvider != nil else { return nil }
        do {
            return try await server.inlayHint(uri: uri, startLine: startLine, startCharacter: startCharacter, endLine: endLine, endCharacter: endCharacter)
        } catch {
            logger.error("Inlay hint failed: \(error)")
            return nil
        }
    }
    
    func requestDocumentHighlight(uri: String, line: Int, character: Int) async -> [DocumentHighlight] {
        guard let server else { return [] }
        guard server.capabilities.documentHighlightProvider != nil else { return [] }
        do {
            return try await server.documentHighlight(uri: uri, line: line, character: character)
        } catch {
            logger.error("Document highlight failed: \(error)")
            return []
        }
    }
    
    func requestCodeAction(uri: String, range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]? = nil) async -> [CodeAction] {
        guard let server else { return [] }
        guard server.capabilities.codeActionProvider != nil else { return [] }
        do {
            let context = CodeActionContext(
                diagnostics: diagnostics,
                only: triggerKinds,
                triggerKind: .invoked
            )
            return try await server.codeAction(uri: uri, range: range, context: context)
        } catch {
            logger.error("Code action failed: \(error)")
            return []
        }
    }
    
    func requestSemanticTokens(uri: String) async -> SemanticTokens? {
        guard let server else { return nil }
        do {
            return try await server.semanticTokens(uri: uri)
        } catch {
            logger.error("Semantic tokens failed: \(error)")
            return nil
        }
    }
    
    func requestSemanticTokensDelta(uri: String, previousResultId: String) async -> SemanticTokensDeltaResponse? {
        guard let server else { return nil }
        do {
            return try await server.semanticTokensDelta(uri: uri, previousResultId: previousResultId)
        } catch {
            logger.error("Semantic token delta failed: \(error)")
            return nil
        }
    }
    
    var currentSemanticTokenMap: LumiSemanticTokenMap? {
        server?.semanticTokenMap
    }

    var completionTriggerCharacters: Set<String> {
        server?.completionTriggerCharacters ?? []
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
        latestDocumentSnapshot = nil
        pendingChanges.removeAll()
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
    
    private func handlePublishDiagnostics(_ params: PublishDiagnosticsParams) {
        guard let currentURI else { return }
        guard params.uri == currentURI else { return }
        currentDiagnostics = params.diagnostics
    }
}
