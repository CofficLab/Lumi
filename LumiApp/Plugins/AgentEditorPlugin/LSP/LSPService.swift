import Foundation
import SwiftUI
import LanguageClient
import LanguageServerProtocol
import os
import MagicKit
import Combine

/// LSP 服务管理器
/// 基于 LanguageClient + LanguageServerProtocol + JSONRPC
/// 完全参考 CodeEdit 的 LSPService 架构
@MainActor
final class LSPService: ObservableObject, SuperLog {
    
    static let shared = LSPService()
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false
    
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
            if Self.verbose {
                EditorPlugin.logger.info("\(Self.t)LSP availability: \(languageId) = \(available ? "yes" : "no")")
            }
            return
        }

        let available = LSPConfig.supportedLanguageIds.contains {
            LSPConfig.findServer(for: $0) != nil
        }
        isAvailable = available
        if Self.verbose {
            EditorPlugin.logger.info("\(Self.t)LSP availability(any) = \(available ? "yes" : "no")")
        }
    }
    
    // MARK: - Server Management
    
    func startServer(for languageId: String, projectPath: String) async {
        if let existing = server {
            if Self.verbose {
                EditorPlugin.logger.info("\(Self.t)Stopping existing server")
            }
            try? await existing.shutdown()
            server = nil
        }
        
        guard let config = LSPConfig.defaultConfig(for: languageId) else {
            EditorPlugin.logger.warning("\(Self.t)No server config for \(languageId)")
            return
        }
        
        if Self.verbose {
            EditorPlugin.logger.info("\(Self.t)Starting server for \(languageId) at \(config.execPath)")
        }
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
            newServer.onProgressUpdate = { [weak self] token, value in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.progressProvider.updateProgress(token: token, value: value)
                    self.objectWillChange.send()
                }
            }
            
            server = newServer
            isInitializing = false
            if Self.verbose {
                EditorPlugin.logger.info("\(Self.t)Server initialized for \(languageId)")
            }
        } catch {
            EditorPlugin.logger.error("\(Self.t)Failed to start server: \(error.localizedDescription)")
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
                EditorPlugin.logger.warning("\(Self.t)No project root")
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
            EditorPlugin.logger.error("\(Self.t)Failed to open document: \(error)")
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
                EditorPlugin.logger.error("\(Self.t)Failed to close document: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Failed to send change: \(error)")
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
                EditorPlugin.logger.error("\(Self.t)Failed to replace document text: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Completion failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Hover failed: \(error)")
            return nil
        }
    }

    /// 请求悬停提示（返回原始 Hover 对象，供调用方自行解析 Markdown）
    func requestHoverRaw(uri: String, line: Int, character: Int) async -> Hover? {
        guard let server else { return nil }
        do {
            return try await server.hover(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Hover raw failed: \(error)")
            return nil
        }
    }
    
    func requestDefinition(uri: String, line: Int, character: Int) async -> Location? {
        guard let server else { return nil }
        do {
            let response: DefinitionResponse = try await server.definition(uri: uri, line: line, character: character)
            return parseDefinitionLocation(response)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Definition failed: \(error)")
            return nil
        }
    }
    
    func requestReferences(uri: String, line: Int, character: Int) async -> [Location] {
        guard let server else { return [] }
        do {
            return try await server.references(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)References failed: \(error)")
            return []
        }
    }

    func requestDocumentSymbols(uri: String) async -> [DocumentSymbol] {
        guard let server else { return [] }
        do {
            return try await server.documentSymbols(uri: uri)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Document symbols failed: \(error)")
            return []
        }
    }

    func requestRename(uri: String, line: Int, character: Int, newName: String) async -> WorkspaceEdit? {
        guard let server else { return nil }
        do {
            return try await server.rename(uri: uri, line: line, character: character, newName: newName)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Rename failed: \(error)")
            return nil
        }
    }

    func requestFormatting(uri: String, tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? {
        guard let server else { return nil }
        do {
            return try await server.formatting(uri: uri, tabSize: tabSize, insertSpaces: insertSpaces)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Formatting failed: \(error)")
            return nil
        }
    }
    
    func requestSignatureHelp(uri: String, line: Int, character: Int) async -> SignatureHelp? {
        guard let server else { return nil }
        guard server.capabilities.signatureHelpProvider != nil else { return nil }
        do {
            return try await server.signatureHelp(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Signature help failed: \(error)")
            return nil
        }
    }
    
    func requestInlayHint(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? {
        guard let server else { return nil }
        guard server.capabilities.inlayHintProvider != nil else { return nil }
        do {
            return try await server.inlayHint(uri: uri, startLine: startLine, startCharacter: startCharacter, endLine: endLine, endCharacter: endCharacter)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Inlay hint failed: \(error)")
            return nil
        }
    }
    
    func requestDocumentHighlight(uri: String, line: Int, character: Int) async -> [DocumentHighlight] {
        guard let server else { return [] }
        guard server.capabilities.documentHighlightProvider != nil else { return [] }
        do {
            return try await server.documentHighlight(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Document highlight failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Code action failed: \(error)")
            return []
        }
    }

    /// 服务器声明 `codeActionProvider.resolveProvider` 时用于补全 `edit` / `command`
    var codeActionResolveSupported: Bool {
        guard let server else { return false }
        switch server.capabilities.codeActionProvider {
        case .optionB(let options):
            return options.resolveProvider == true
        default:
            return false
        }
    }

    func resolveCodeAction(_ action: CodeAction) async -> CodeAction? {
        guard codeActionResolveSupported else { return nil }
        guard let server else { return nil }
        do {
            return try await server.codeActionResolve(action)
        } catch {
            EditorPlugin.logger.error("\(Self.t)codeAction/resolve failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 当前语言服务器是否支持 inlay hint
    var supportsInlayHints: Bool {
        guard let server else { return false }
        return server.capabilities.inlayHintProvider != nil
    }
    
    func requestSemanticTokens(uri: String) async -> SemanticTokens? {
        guard let server else { return nil }
        do {
            return try await server.semanticTokens(uri: uri)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Semantic tokens failed: \(error)")
            return nil
        }
    }
    
    func requestSemanticTokensDelta(uri: String, previousResultId: String) async -> SemanticTokensDeltaResponse? {
        guard let server else { return nil }
        do {
            return try await server.semanticTokensDelta(uri: uri, previousResultId: previousResultId)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Semantic token delta failed: \(error)")
            return nil
        }
    }
    
    func requestDeclaration(uri: String, line: Int, character: Int) async -> DeclarationResponse {
        guard let server else { return nil }
        guard server.capabilities.declarationProvider != nil else { return nil }
        do {
            return try await server.declaration(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Declaration failed: \(error)")
            return nil
        }
    }
    
    func requestTypeDefinition(uri: String, line: Int, character: Int) async -> TypeDefinitionResponse {
        guard let server else { return nil }
        guard server.capabilities.typeDefinitionProvider != nil else { return nil }
        do {
            return try await server.typeDefinition(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Type definition failed: \(error)")
            return nil
        }
    }
    
    func requestImplementation(uri: String, line: Int, character: Int) async -> ImplementationResponse {
        guard let server else { return nil }
        guard server.capabilities.implementationProvider != nil else { return nil }
        do {
            return try await server.implementation(uri: uri, line: line, character: character)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Implementation failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Folding range failed: \(error)")
            return []
        }
    }
    
    // MARK: Selection Range
    
    func requestSelectionRange(uri: String, line: Int, character: Int) async -> [SelectionRange] {
        guard let server else { return [] }
        do {
            return try await server.selectionRange(uri: uri, line: line, character: character) ?? []
        } catch {
            EditorPlugin.logger.error("\(Self.t)Selection range failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Document link failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Resolve document link failed: \(error)")
            return nil
        }
    }
    
    func resolveDocumentLinkLSP(_ link: DocumentLink) async -> DocumentLink? {
        guard let server else { return nil }
        do {
            return try await server.resolveDocumentLink(link)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Resolve document link failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Document color failed: \(error)")
            return []
        }
    }
    
    func requestColorPresentation(uri: String, red: Double, green: Double, blue: Double, alpha: Double, range: LSPRange) async -> [ColorPresentation] {
        guard let server else { return [] }
        let color = Color(red: Float(red), green: Float(green), blue: Float(blue), alpha: Float(alpha))
        do {
            return try await server.colorPresentation(uri: uri, color: color, range: range)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Color presentation failed: \(error)")
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
            EditorPlugin.logger.error("\(Self.t)Call hierarchy prepare failed: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyIncomingCalls(item: CallHierarchyItem) async -> [CallHierarchyIncomingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyIncomingCalls(item: item)) ?? []
        } catch {
            EditorPlugin.logger.error("\(Self.t)Call hierarchy incoming calls failed: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyOutgoingCalls(item: CallHierarchyItem) async -> [CallHierarchyOutgoingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyOutgoingCalls(item: item)) ?? []
        } catch {
            EditorPlugin.logger.error("\(Self.t)Call hierarchy outgoing calls failed: \(error)")
            return []
        }
    }
    
    // MARK: Workspace Symbol
    
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse {
        guard let server else { return nil }
        do {
            return try await server.workspaceSymbol(query: query)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Workspace symbol failed: \(error)")
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
        if let commands = server.capabilities.executeCommandProvider?.commands,
           !commands.contains(command) {
            EditorPlugin.logger.warning("\(Self.t)Command \(command) not listed in server capabilities; attempting anyway")
        }
        do {
            return try await server.executeCommand(command: command, arguments: arguments)
        } catch {
            EditorPlugin.logger.error("\(Self.t)Execute command failed: \(error)")
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
        progressProvider.clear()
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
