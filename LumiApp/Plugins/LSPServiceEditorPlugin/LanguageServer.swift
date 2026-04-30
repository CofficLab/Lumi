import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import os
import MagicKit

/// 语言服务器包装器
/// 注意：不使用 @MainActor，让调用方自行处理并发
final class LanguageServer: @unchecked Sendable, SuperLog {
    static var emoji: String { "🌐" }
    static var verbose: Bool { false }

    let languageId: String
    let config: LSPConfig.ServerConfig
    private(set) var server: InitializingServer
    var capabilities: ServerCapabilities
    private(set) var pid: pid_t
    private(set) var rootPath: URL
    private(set) var openDocuments: [String: Int] = [:]
    private(set) var documentContents: [String: String] = [:]
    private(set) var semanticTokenMap: SemanticTokenMap?
    private var eventTask: Task<Void, Never>?
    private let documentStateLock = NSLock()
    var onPublishDiagnostics: ((PublishDiagnosticsParams) -> Void)?
    var onProgressUpdate: ((String, LanguageServerProtocol.LSPAny?) -> Void)?
    
    private init(
        languageId: String,
        config: LSPConfig.ServerConfig,
        server: InitializingServer,
        pid: pid_t,
        capabilities: ServerCapabilities,
        rootPath: URL
    ) {
        self.languageId = languageId
        self.config = config
        self.server = server
        self.pid = pid
        self.capabilities = capabilities
        self.rootPath = rootPath
        self.semanticTokenMap = SemanticTokenMap(semanticCapability: capabilities.semanticTokensProvider)
    }
    
    static func create(
        languageId: String,
        config: LSPConfig.ServerConfig,
        workspacePath: String,
        workspaceFolders: [LanguageServerProtocol.WorkspaceFolder]? = nil,
        initializationOptions: LanguageServerProtocol.LSPAny? = nil
    ) async throws -> LanguageServer {
        if LSPService.verbose {
            LSPService.logger.info(
                "\(Self.t)正在创建 \(languageId) 服务器: exec=\(config.execPath, privacy: .public), args=\(config.arguments.joined(separator: " "), privacy: .public), workspacePath=\(workspacePath, privacy: .public), workspaceFolders=\(workspaceFolders?.count ?? 0), hasInitOptions=\(initializationOptions != nil)"
            )
        }
        
        let execParams = Process.ExecutionParameters(
            path: config.execPath,
            arguments: config.arguments,
            environment: config.env.isEmpty ? nil : config.env
        )
        
        let (channel, process) = try DataChannel.localProcessChannel(
            parameters: execParams,
            terminationHandler: {
                LSPService.logger.error("\(LanguageServer.t)数据通道意外终止")
            }
        )
        
        let connection = JSONRPCServerConnection(dataChannel: channel)
        let initServer = InitializingServer(
            server: connection,
            initializeParamsProvider: Self.makeInitParams(
                workspacePath: workspacePath,
                workspaceFolders: workspaceFolders,
                initializationOptions: initializationOptions
            )
        )
        
        let initResult = try await initServer.initializeIfNeeded()
        
        if LSPService.verbose {
            LSPService.logger.info(
                "\(Self.t)服务器已初始化，PID: \(process.processIdentifier), rootUri=file://\(workspacePath, privacy: .public), workspaceFolders=\(workspaceFolders?.count ?? 0), definitionProvider=\(String(describing: initResult.capabilities.definitionProvider), privacy: .public)"
            )
        }
        
        let languageServer = LanguageServer(
            languageId: languageId,
            config: config,
            server: initServer,
            pid: process.processIdentifier,
            capabilities: initResult.capabilities,
            rootPath: URL(filePath: workspacePath)
        )
        languageServer.startListeningToEvents()
        return languageServer
    }
    
    // MARK: - Init Params (简化版，参考 CodeEdit 的核心能力)
    
    static func makeInitParams(
        workspacePath: String,
        workspaceFolders: [LanguageServerProtocol.WorkspaceFolder]? = nil,
        initializationOptions: LanguageServerProtocol.LSPAny? = nil
    ) -> InitializingServer.InitializeParamsProvider {
        {
            let textDocumentCaps = TextDocumentClientCapabilities(
                completion: CompletionClientCapabilities(
                    dynamicRegistration: true,
                    completionItem: CompletionClientCapabilities.CompletionItem(
                        snippetSupport: true,
                        commitCharactersSupport: true,
                        documentationFormat: [MarkupKind.markdown, MarkupKind.plaintext],
                        deprecatedSupport: true,
                        preselectSupport: true,
                        tagSupport: ValueSet(valueSet: [CompletionItemTag.deprecated]),
                        insertReplaceSupport: true,
                        resolveSupport: CompletionClientCapabilities.CompletionItem.ResolveSupport(
                            properties: ["documentation", "detail"]
                        ),
                        insertTextModeSupport: ValueSet(valueSet: [InsertTextMode.adjustIndentation]),
                        labelDetailsSupport: true
                    ),
                    completionItemKind: nil,
                    contextSupport: true,
                    insertTextMode: InsertTextMode.asIs,
                    completionList: nil
                ),
                codeAction: CodeActionClientCapabilities(
                    dynamicRegistration: true,
                    codeActionLiteralSupport: CodeActionClientCapabilities.CodeActionLiteralSupport(
                        codeActionKind: ValueSet(valueSet: [
                            CodeActionKind.Quickfix,
                            CodeActionKind.Refactor,
                            CodeActionKind.RefactorExtract,
                            CodeActionKind.RefactorInline,
                            CodeActionKind.RefactorRewrite,
                            CodeActionKind.Source,
                            CodeActionKind.SourceOrganizeImports,
                            CodeActionKind.SourceFixAll,
                            CodeActionKind.Empty
                        ])
                    ),
                    isPreferredSupport: true,
                    disabledSupport: true,
                    resolveSupport: CodeActionClientCapabilities.ResolveSupport(properties: ["edit", "command"])
                ),
                semanticTokens: SemanticTokensClientCapabilities(
                    dynamicRegistration: false,
                    requests: .init(range: false, delta: true),
                    tokenTypes: SemanticTokenTypes.allStrings,
                    tokenModifiers: SemanticTokenModifiers.allStrings,
                    formats: [.relative],
                    overlappingTokenSupport: true,
                    multilineTokenSupport: true,
                    serverCancelSupport: false,
                    augmentsSyntaxTokens: true
                ),
                inlayHint: InlayHintClientCapabilities(dynamicRegistration: false)
            )
            
            let workspaceCaps = ClientCapabilities.Workspace(
                applyEdit: true,
                workspaceEdit: nil,
                didChangeConfiguration: DidChangeConfigurationClientCapabilities(dynamicRegistration: true),
                didChangeWatchedFiles: DidChangeWatchedFilesClientCapabilities(dynamicRegistration: true),
                symbol: WorkspaceSymbolClientCapabilities(
                    dynamicRegistration: true,
                    symbolKind: nil,
                    tagSupport: nil,
                    resolveSupport: []
                ),
                executeCommand: GenericDynamicRegistration(dynamicRegistration: true),
                workspaceFolders: true,
                configuration: true,
                semanticTokens: nil,
                codeLens: nil,
                fileOperations: nil
            )
            
            let windowCaps = WindowClientCapabilities(
                workDoneProgress: true,
                showMessage: ShowMessageRequestClientCapabilities(
                    messageActionItem: ShowMessageRequestClientCapabilities.MessageActionItemCapabilities(
                        additionalPropertiesSupport: true
                    )
                ),
                showDocument: ShowDocumentClientCapabilities(support: true)
            )
            
            let capabilities = ClientCapabilities(
                workspace: workspaceCaps,
                textDocument: textDocumentCaps,
                window: windowCaps,
                general: nil,
                experimental: nil
            )
            
            // Phase 4: workspaceFolders 不再为 nil，而是由调用方传入
            let folders = workspaceFolders ?? [LanguageServerProtocol.WorkspaceFolder(uri: "file://" + workspacePath, name: URL(filePath: workspacePath).lastPathComponent)]
            
            return InitializeParams(
                processId: nil,
                locale: nil,
                rootPath: nil,
                rootUri: "file://" + workspacePath,
                initializationOptions: initializationOptions,
                capabilities: capabilities,
                trace: nil,
                workspaceFolders: folders
            )
        }
    }
    
    // MARK: - Document Lifecycle

    private func withDocumentState<T>(
        _ body: (_ openDocuments: inout [String: Int], _ documentContents: inout [String: String]) -> T
    ) -> T {
        documentStateLock.lock()
        defer { documentStateLock.unlock() }
        return body(&openDocuments, &documentContents)
    }
    
    func openDocument(uri: String, languageId: String, text: String, version: Int = 0) async throws {
        let shouldOpen = withDocumentState { openDocuments, documentContents in
            guard openDocuments[uri] == nil else { return false }
            openDocuments[uri] = version
            documentContents[uri] = text
            return true
        }
        guard shouldOpen else { return }
        
        let doc = TextDocumentItem(uri: uri, languageId: languageId, version: version, text: text)
        do {
            try await server.textDocumentDidOpen(DidOpenTextDocumentParams(textDocument: doc))
        } catch {
            withDocumentState { openDocuments, documentContents in
                openDocuments.removeValue(forKey: uri)
                documentContents.removeValue(forKey: uri)
            }
            throw error
        }
        if LSPService.verbose {
            LSPService.logger.debug("\(Self.t)已打开: \(uri)")
        }
    }
    
    func closeDocument(uri: String) async throws {
        let shouldClose = withDocumentState { openDocuments, documentContents in
            guard openDocuments[uri] != nil else { return false }
            openDocuments.removeValue(forKey: uri)
            documentContents.removeValue(forKey: uri)
            return true
        }
        guard shouldClose else { return }
        
        try await server.textDocumentDidClose(DidCloseTextDocumentParams(textDocument: TextDocumentIdentifier(uri: uri)))
        if LSPService.verbose {
            LSPService.logger.debug("\(Self.t)已关闭: \(uri)")
        }
    }

    func documentDidSave(uri: String, text: String? = nil) async throws {
        let shouldSave = withDocumentState { openDocuments, documentContents in
            guard openDocuments[uri] != nil else { return false }
            if let text {
                documentContents[uri] = text
            }
            return true
        }
        guard shouldSave else { return }

        try await server.textDocumentDidSave(
            DidSaveTextDocumentParams(
                textDocument: TextDocumentIdentifier(uri: uri),
                text: text
            )
        )
        if LSPService.verbose {
            LSPService.logger.debug("\(Self.t)已保存: \(uri)")
        }
    }
    
    func documentDidChange(uri: String, text: String, version explicitVersion: Int? = nil) async throws {
        let newVersion: Int? = withDocumentState { openDocuments, documentContents in
            guard let currentVersion = openDocuments[uri] else { return nil }
            let newVersion = explicitVersion ?? (currentVersion + 1)
            openDocuments[uri] = newVersion
            documentContents[uri] = text
            return newVersion
        }
        guard let newVersion else { return }
        
        let event = TextDocumentContentChangeEvent(range: nil, rangeLength: nil, text: text)
        let params = DidChangeTextDocumentParams(
            textDocument: VersionedTextDocumentIdentifier(uri: uri, version: newVersion),
            contentChanges: [event]
        )
        try await server.textDocumentDidChange(params)
    }
    
    struct DocumentChange: Sendable {
        let range: LSPRange
        let text: String
    }
    
    func documentDidChange(uri: String, changes: [DocumentChange], fullText: String?, version explicitVersion: Int? = nil) async throws {
        guard !changes.isEmpty else { return }
        
        let syncKind = resolveDocumentSyncKind()
        let snapshot: (Int, String?, String?)? = withDocumentState { openDocuments, documentContents in
            guard let currentVersion = openDocuments[uri] else { return nil }
            let newVersion = explicitVersion ?? (currentVersion + 1)
            let existingContent = documentContents[uri]
            let textToStore: String?

            switch syncKind {
            case .incremental:
                textToStore = applyChanges(changes, to: existingContent) ?? fullText
            case .full:
                textToStore = fullText ?? existingContent.flatMap { applyChanges(changes, to: $0) }
            case .none:
                textToStore = existingContent
            }

            openDocuments[uri] = newVersion
            if let textToStore {
                documentContents[uri] = textToStore
            }

            return (newVersion, existingContent, textToStore)
        }
        guard let (newVersion, existingContent, storedText) = snapshot else { return }
        
        switch syncKind {
        case .incremental:
            let events = changes.map {
                TextDocumentContentChangeEvent(range: $0.range, rangeLength: nil, text: $0.text)
            }
            try await server.textDocumentDidChange(
                DidChangeTextDocumentParams(
                    textDocument: VersionedTextDocumentIdentifier(uri: uri, version: newVersion),
                    contentChanges: events
                )
            )
        case .full:
            let textToSend: String
            if let storedText {
                textToSend = storedText
            } else if let existingContent, let updated = applyChanges(changes, to: existingContent) {
                textToSend = updated
            } else {
                return
            }
            let event = TextDocumentContentChangeEvent(range: nil, rangeLength: nil, text: textToSend)
            try await server.textDocumentDidChange(
                DidChangeTextDocumentParams(
                    textDocument: VersionedTextDocumentIdentifier(uri: uri, version: newVersion),
                    contentChanges: [event]
                )
            )
        case .none:
            return
        }
    }
    
    // MARK: - LSP Capabilities
    
    func completion(uri: String, line: Int, character: Int) async throws -> CompletionResponse {
        let params = CompletionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character),
            context: CompletionContext(triggerKind: .invoked, triggerCharacter: nil)
        )
        return try await server.completion(params)
    }
    
    func hover(uri: String, line: Int, character: Int) async throws -> HoverResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.hover(params)
    }
    
    func definition(uri: String, line: Int, character: Int) async throws -> DefinitionResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.definition(params)
    }
    
    func references(uri: String, line: Int, character: Int) async throws -> [Location] {
        let params = ReferenceParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character),
            context: ReferenceContext(includeDeclaration: true)
        )
        return try await server.references(params) ?? []
    }
    
    func documentSymbols(uri: String) async throws -> [DocumentSymbol] {
        let params = DocumentSymbolParams(textDocument: TextDocumentIdentifier(uri: uri))
        guard case .optionA(let symbols) = try await server.documentSymbol(params) else { return [] }
        return symbols
    }
    
    func rename(uri: String, line: Int, character: Int, newName: String) async throws -> WorkspaceEdit? {
        let params = RenameParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character),
            newName: newName
        )
        return try await server.rename(params)
    }
    
    func formatting(uri: String, tabSize: Int, insertSpaces: Bool) async throws -> [TextEdit]? {
        let params = DocumentFormattingParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            options: FormattingOptions(tabSize: tabSize, insertSpaces: insertSpaces)
        )
        return try await server.formatting(params)
    }
    
    func semanticTokens(uri: String) async throws -> SemanticTokens? {
        let params = SemanticTokensParams(textDocument: TextDocumentIdentifier(uri: uri))
        return try await server.semanticTokensFull(params)
    }
    
    func semanticTokensDelta(uri: String, previousResultId: String) async throws -> SemanticTokensDeltaResponse {
        let params = SemanticTokensDeltaParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            previousResultId: previousResultId
        )
        return try await server.semanticTokensFullDelta(params)
    }
    
    func signatureHelp(uri: String, line: Int, character: Int) async throws -> SignatureHelpResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.signatureHelp(params)
    }
    
    func inlayHint(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async throws -> InlayHintResponse {
        let range = LSPRange(
            start: Position(line: startLine, character: startCharacter),
            end: Position(line: endLine, character: endCharacter)
        )
        let params = InlayHintParams(
            workDoneToken: nil,
            textDocument: TextDocumentIdentifier(uri: uri),
            range: range
        )
        return try await server.inlayHint(params)
    }
    
    func documentHighlight(uri: String, line: Int, character: Int) async throws -> [DocumentHighlight] {
        let params = DocumentHighlightParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.documentHighlight(params) ?? []
    }
    
    func codeAction(
        uri: String,
        range: LSPRange,
        context: CodeActionContext
    ) async throws -> [CodeAction] {
        let params = CodeActionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            range: range,
            context: context
        )
        let response = try await server.codeAction(params)
        return parseCodeActionResponse(response)
    }

    func codeActionResolve(_ action: CodeAction) async throws -> CodeAction {
        try await server.codeActionResolve(action)
    }
    
    func declaration(uri: String, line: Int, character: Int) async throws -> DeclarationResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.declaration(params)
    }
    
    func typeDefinition(uri: String, line: Int, character: Int) async throws -> TypeDefinitionResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.typeDefinition(params)
    }
    
    func implementation(uri: String, line: Int, character: Int) async throws -> ImplementationResponse {
        let params = TextDocumentPositionParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.implementation(params)
    }
    
    // MARK: - New LSP Capabilities
    
    // MARK: Folding Range
    
    func foldingRange(uri: String) async throws -> FoldingRangeResponse {
        let params = FoldingRangeParams(textDocument: TextDocumentIdentifier(uri: uri))
        return try await server.sendRequest(.foldingRange(params, ClientRequest.NullHandler))
    }
    
    // MARK: Selection Range
    
    func selectionRange(uri: String, line: Int, character: Int) async throws -> [SelectionRange]? {
        let params = SelectionRangeParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            positions: [Position(line: line, character: character)]
        )
        return try await server.sendRequest(.selectionRange(params, ClientRequest.NullHandler))
    }
    
    // MARK: Document Link
    
    func documentLink(uri: String) async throws -> [DocumentLink]? {
        // DocumentLinkParams in LSP lib doesn't have textDocument field - need to work around
        let params = DocumentLinkParams()
        return try await server.sendRequest(.documentLink(params, ClientRequest.NullHandler))
    }
    
    func resolveDocumentLink(_ link: DocumentLink) async throws -> DocumentLink {
        return try await server.sendRequest(.documentLinkResolve(link, ClientRequest.NullHandler))
    }
    
    // MARK: Document Color
    
    func documentColor(uri: String) async throws -> [ColorInformation] {
        let params = DocumentColorParams(textDocument: TextDocumentIdentifier(uri: uri))
        return try await server.sendRequest(.documentColor(params, ClientRequest.NullHandler))
    }
    
    func colorPresentation(uri: String, color: Color, range: LSPRange) async throws -> [ColorPresentation] {
        let params = ColorPresentationParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            color: color,
            range: range
        )
        return try await server.sendRequest(.colorPresentation(params, ClientRequest.NullHandler))
    }
    
    // MARK: Call Hierarchy
    
    func callHierarchyPrepare(uri: String, line: Int, character: Int) async throws -> [CallHierarchyItem]? {
        let params = CallHierarchyPrepareParams(
            textDocument: TextDocumentIdentifier(uri: uri),
            position: Position(line: line, character: character)
        )
        return try await server.sendRequest(.prepareCallHierarchy(params, ClientRequest.NullHandler))
    }
    
    func callHierarchyIncomingCalls(item: CallHierarchyItem) async throws -> [CallHierarchyIncomingCall]? {
        let params = CallHierarchyIncomingCallsParams(item: item)
        return try await server.sendRequest(.callHierarchyIncomingCalls(params, ClientRequest.NullHandler))
    }
    
    func callHierarchyOutgoingCalls(item: CallHierarchyItem) async throws -> [CallHierarchyOutgoingCall]? {
        let params = CallHierarchyOutgoingCallsParams(item: item)
        return try await server.sendRequest(.callHierarchyOutgoingCalls(params, ClientRequest.NullHandler))
    }
    
    // MARK: Workspace Symbol
    
    func workspaceSymbol(query: String) async throws -> WorkspaceSymbolResponse {
        let params = WorkspaceSymbolParams(query: query)
        return try await server.sendRequest(.workspaceSymbol(params, ClientRequest.NullHandler))
    }
    
    // MARK: Execute Command
    
    func executeCommand(command: String, arguments: [LanguageServerProtocol.LSPAny]? = nil) async throws -> LSPAny? {
        let params = ExecuteCommandParams(command: command, arguments: arguments)
        return try await server.sendRequest(.workspaceExecuteCommand(params, ClientRequest.NullHandler))
    }
    
    // MARK: Shutdown
    
    func shutdown() async throws {
        if LSPService.verbose {
            LSPService.logger.info("\(Self.t)正在关闭 \(self.languageId) 服务器")
        }
        eventTask?.cancel()
        eventTask = nil
        try await server.shutdownAndExit()
        if LSPService.verbose {
            LSPService.logger.info("\(Self.t)服务器已关闭")
        }
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    // MARK: - Event Listening
    
    private func startListeningToEvents() {
        eventTask?.cancel()
        eventTask = Task.detached { [weak self] in
            guard let self else { return }
            for await event in self.server.eventSequence {
                if Task.isCancelled { return }
                switch event {
                case let .notification(notification):
                    switch notification {
                    case let .textDocumentPublishDiagnostics(params):
                        self.onPublishDiagnostics?(params)
                    case let .protocolProgress(params):
                        // Handle $/progress notifications
                        // ProgressToken = TwoTypeOption<Int, String>
                        let tokenStr: String
                        switch params.token {
                        case .optionA(let i): tokenStr = String(i)
                        case .optionB(let s): tokenStr = s
                        }
                        self.onProgressUpdate?(tokenStr, params.value)
                    case let .windowShowMessage(params):
                        if LSPService.verbose {
                            LSPService.logger.info("\(LanguageServer.t)LSP 消息 [\(params.type.rawValue)]: \(params.message)")
                        }
                    default:
                        continue
                    }
                default:
                    continue
                }
            }
        }
    }
    
    // MARK: - Document Sync Helpers
    
    private func resolveDocumentSyncKind() -> TextDocumentSyncKind {
        switch capabilities.textDocumentSync {
        case .optionA(let options):
            return options.change ?? .none
        case .optionB(let kind):
            return kind
        default:
            return .none
        }
    }

    var completionTriggerCharacters: Set<String> {
        Set(capabilities.completionProvider?.triggerCharacters ?? [])
    }
    
    /// CodeActionResponse = [TwoTypeOption<Command, CodeAction>]?
    private func parseCodeActionResponse(_ response: CodeActionResponse) -> [CodeAction] {
        guard let response else { return [] }
        return response.compactMap { item -> CodeAction? in
            switch item {
            case .optionA(let command):
                return CodeAction(title: command.title, command: command)
            case .optionB(let action):
                return action
            }
        }
    }
    
    private func applyChanges(_ changes: [DocumentChange], to content: String?) -> String? {
        guard let content else { return nil }
        var result = content
        for change in changes {
            guard let nsRange = nsRange(from: change.range, in: result) else { return nil }
            if let swiftRange = Range(nsRange, in: result) {
                result.replaceSubrange(swiftRange, with: change.text)
            } else {
                return nil
            }
        }
        return result
    }
    
    private func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        let startOffset = utf16Offset(for: lspRange.start, in: content)
        let endOffset = utf16Offset(for: lspRange.end, in: content)
        guard let startOffset, let endOffset, endOffset >= startOffset else { return nil }
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }
    
    private func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0
        
        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }
        
        guard line == position.line else { return nil }
        
        let targetOffset = lineStartOffset + position.character
        return min(targetOffset, content.utf16.count)
    }
}
