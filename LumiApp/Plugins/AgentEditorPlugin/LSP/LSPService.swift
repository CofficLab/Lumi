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
final class LSPService: ObservableObject {
    
    static let shared = LSPService()
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.service")
    
    // MARK: - Published State
    
    @Published var currentDiagnostics: [Diagnostic] = []
    @Published var isAvailable: Bool = false
    @Published var activeLanguageId: String?
    @Published var isInitializing: Bool = false
    
    // MARK: - Properties
    
    private var server: LanguageServer?
    private var currentURI: String?
    private var currentVersion: Int = 0
    private var projectRootPath: String?
    
    private var changeDebounceTimer: Timer?
    private var pendingChanges: [LanguageServer.DocumentChange] = []
    private var latestDocumentSnapshot: String?
    
    var onHover: ((String?) -> Void)?
    
    init() {
        checkAvailability()
    }
    
    // MARK: - Availability
    
    func checkAvailability(for languageId: String? = nil) {
        if let languageId {
            let available = LSPConfig.findServer(for: languageId) != nil
            isAvailable = available
            logger.info("LSP availability: \(languageId) = \(available ? "yes" : "no")")
            return
        }

        let available = LSPConfig.supportedLanguageIds.contains {
            LSPConfig.findServer(for: $0) != nil
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
        
        guard let config = LSPConfig.defaultConfig(for: languageId) else {
            logger.warning("No server config for \(languageId)")
            return
        }
        
        logger.info("Starting server for \(languageId) at \(config.execPath)")
        isInitializing = true
        activeLanguageId = languageId
        projectRootPath = projectPath
        
        do {
            let newServer = try await LanguageServer.create(
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
    
    func requestDeclaration(uri: String, line: Int, character: Int) async -> DeclarationResponse {
        guard let server else { return nil }
        guard server.capabilities.declarationProvider != nil else { return nil }
        do {
            return try await server.declaration(uri: uri, line: line, character: character)
        } catch {
            logger.error("Declaration failed: \(error)")
            return nil
        }
    }
    
    func requestTypeDefinition(uri: String, line: Int, character: Int) async -> TypeDefinitionResponse {
        guard let server else { return nil }
        guard server.capabilities.typeDefinitionProvider != nil else { return nil }
        do {
            return try await server.typeDefinition(uri: uri, line: line, character: character)
        } catch {
            logger.error("Type definition failed: \(error)")
            return nil
        }
    }
    
    func requestImplementation(uri: String, line: Int, character: Int) async -> ImplementationResponse {
        guard let server else { return nil }
        guard server.capabilities.implementationProvider != nil else { return nil }
        do {
            return try await server.implementation(uri: uri, line: line, character: character)
        } catch {
            logger.error("Implementation failed: \(error)")
            return nil
        }
    }
    
    var currentSemanticTokenMap: SemanticTokenMap? {
        server?.semanticTokenMap
    }

    var completionTriggerCharacters: Set<String> {
        server?.completionTriggerCharacters ?? []
    }
    
    // MARK: - New LSP Features
    
    // MARK: Folding Range
    
    func requestFoldingRange(uri: String) async -> [FoldingRange] {
        guard let server else { return [] }
        guard server.capabilities.foldingRangeProvider != nil else { return [] }
        do {
            let response = try await server.foldingRange(uri: uri)
            return response ?? []
        } catch {
            logger.error("Folding range failed: \(error)")
            return []
        }
    }
    
    // MARK: Selection Range
    
    func requestSelectionRange(uri: String, line: Int, character: Int) async -> [SelectionRange] {
        guard let server else { return [] }
        do {
            return try await server.selectionRange(uri: uri, line: line, character: character) ?? []
        } catch {
            logger.error("Selection range failed: \(error)")
            return []
        }
    }
    
    // MARK: Document Link
    
    func requestDocumentLinks(uri: String) async -> [DocumentLink] {
        guard let server else { return [] }
        guard server.capabilities.documentLinkProvider != nil else { return [] }
        do {
            return try await server.documentLink(uri: uri) ?? []
        } catch {
            logger.error("Document link failed: \(error)")
            return []
        }
    }
    
    func resolveDocumentLink(_ link: EditorDocumentLink) async -> DocumentLink? {
        guard let server else { return nil }
        let lspLink = DocumentLink(
            range: link.range,
            target: link.target,
            tooltip: link.tooltip,
            data: link.data
        )
        do {
            return try await server.resolveDocumentLink(lspLink)
        } catch {
            logger.error("Resolve document link failed: \(error)")
            return nil
        }
    }
    
    func resolveDocumentLinkLSP(_ link: DocumentLink) async -> DocumentLink? {
        guard let server else { return nil }
        do {
            return try await server.resolveDocumentLink(link)
        } catch {
            logger.error("Resolve document link failed: \(error)")
            return nil
        }
    }
    
    // MARK: Document Color
    
    func requestDocumentColors(uri: String) async -> [ColorInformation] {
        guard let server else { return [] }
        guard server.capabilities.colorProvider != nil else { return [] }
        do {
            return try await server.documentColor(uri: uri)
        } catch {
            logger.error("Document color failed: \(error)")
            return []
        }
    }
    
    func requestColorPresentation(uri: String, red: Double, green: Double, blue: Double, alpha: Double, range: LSPRange) async -> [ColorPresentation] {
        guard let server else { return [] }
        let color = Color(red: Float(red), green: Float(green), blue: Float(blue), alpha: Float(alpha))
        do {
            return try await server.colorPresentation(uri: uri, color: color, range: range)
        } catch {
            logger.error("Color presentation failed: \(error)")
            return []
        }
    }
    
    // MARK: Call Hierarchy
    
    func requestCallHierarchyPrepare(uri: String, line: Int, character: Int) async -> [CallHierarchyItem] {
        guard let server else { return [] }
        guard server.capabilities.callHierarchyProvider != nil else { return [] }
        do {
            return try await server.callHierarchyPrepare(uri: uri, line: line, character: character) ?? []
        } catch {
            logger.error("Call hierarchy prepare failed: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyIncomingCalls(item: CallHierarchyItem) async -> [CallHierarchyIncomingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyIncomingCalls(item: item)) ?? []
        } catch {
            logger.error("Call hierarchy incoming calls failed: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyOutgoingCalls(item: CallHierarchyItem) async -> [CallHierarchyOutgoingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyOutgoingCalls(item: item)) ?? []
        } catch {
            logger.error("Call hierarchy outgoing calls failed: \(error)")
            return []
        }
    }
    
    // MARK: Workspace Symbol
    
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse {
        guard let server else { return nil }
        do {
            return try await server.workspaceSymbol(query: query)
        } catch {
            logger.error("Workspace symbol failed: \(error)")
            return nil
        }
    }
    
    // MARK: Will Save / Will Save Wait Until
    
    // Note: willSave and willSaveWaitUntil are available via ServerConnection
    // but not exposed via InitializingServer convenience methods
    var supportsWillSave: Bool {
        guard let server else { return false }
        switch server.capabilities.textDocumentSync {
        case .optionA(let options):
            return options.willSave == true
        default:
            return false
        }
    }
    
    var supportsWillSaveWaitUntil: Bool {
        guard let server else { return false }
        switch server.capabilities.textDocumentSync {
        case .optionA(let options):
            return options.willSaveWaitUntil == true
        default:
            return false
        }
    }
    
    // MARK: Execute Command
    
    func executeCommand(command: String, arguments: [LanguageServerProtocol.LSPAny]? = nil) async -> LanguageServerProtocol.LSPAny? {
        guard let server else { return nil }
        guard let commands = server.capabilities.executeCommandProvider?.commands,
              commands.contains(command) else {
            logger.warning("Command \(command) not supported by server")
            return nil
        }
        do {
            return try await server.executeCommand(command: command, arguments: arguments)
        } catch {
            logger.error("Execute command failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Progress Notifications
    
    let progressProvider = LSPProgressProvider()
    
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

    /// DeclarationResponse / TypeDefinitionResponse / ImplementationResponse
    /// 三者均为 ThreeTypeOption<Location, [Location], [LocationLink]>? 结构
    nonisolated func parseLocationResponse(_ response: ThreeTypeOption<Location, [Location], [LocationLink]>?) -> Location? {
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
