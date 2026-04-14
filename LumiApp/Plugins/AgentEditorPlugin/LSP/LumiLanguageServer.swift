import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import os

/// Lumi 的语言服务器包装器
/// 参考 CodeEdit 的 LanguageServer.swift
/// 注意：不使用 @MainActor，让调用方自行处理并发
final class LumiLanguageServer: @unchecked Sendable {
    
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.server")
    
    let languageId: String
    let config: LumiLSPConfig.ServerConfig
    private(set) var server: InitializingServer
    var capabilities: ServerCapabilities
    private(set) var pid: pid_t
    private(set) var rootPath: URL
    private(set) var openDocuments: [String: Int] = [:]
    
    private init(
        languageId: String,
        config: LumiLSPConfig.ServerConfig,
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
    }
    
    static func create(
        languageId: String,
        config: LumiLSPConfig.ServerConfig,
        workspacePath: String
    ) async throws -> LumiLanguageServer {
        Self.logger.info("Creating server for \(languageId)")
        
        let execParams = Process.ExecutionParameters(
            path: config.execPath,
            arguments: config.arguments,
            environment: config.env.isEmpty ? nil : config.env
        )
        
        let (channel, process) = try DataChannel.localProcessChannel(
            parameters: execParams,
            terminationHandler: {
                // Can't reference @MainActor logger from Sendable closure
                print("LSP: Data channel terminated unexpectedly")
            }
        )
        
        let connection = JSONRPCServerConnection(dataChannel: channel)
        let initServer = InitializingServer(
            server: connection,
            initializeParamsProvider: Self.makeInitParams(workspacePath: workspacePath)
        )
        
        let initResult = try await initServer.initializeIfNeeded()
        
        Self.logger.info("Server initialized, PID: \(process.processIdentifier)")
        
        return LumiLanguageServer(
            languageId: languageId,
            config: config,
            server: initServer,
            pid: process.processIdentifier,
            capabilities: initResult.capabilities,
            rootPath: URL(filePath: workspacePath)
        )
    }
    
    // MARK: - Init Params (简化版，参考 CodeEdit 的核心能力)
    
    static func makeInitParams(workspacePath: String) -> InitializingServer.InitializeParamsProvider {
        {
            let textDocumentCaps = TextDocumentClientCapabilities(
                completion: CompletionClientCapabilities(
                    dynamicRegistration: true,
                    completionItem: CompletionClientCapabilities.CompletionItem(
                        snippetSupport: true,
                        commitCharactersSupport: true,
                        documentationFormat: [MarkupKind.plaintext],
                        deprecatedSupport: true,
                        preselectSupport: true,
                        tagSupport: ValueSet(valueSet: [CompletionItemTag.deprecated]),
                        insertReplaceSupport: true,
                        resolveSupport: CompletionClientCapabilities.CompletionItem.ResolveSupport(
                            properties: ["documentation", "details"]
                        ),
                        insertTextModeSupport: ValueSet(valueSet: [InsertTextMode.adjustIndentation]),
                        labelDetailsSupport: true
                    ),
                    completionItemKind: ValueSet(valueSet: [CompletionItemKind.text, CompletionItemKind.method]),
                    contextSupport: true,
                    insertTextMode: InsertTextMode.asIs,
                    completionList: CompletionClientCapabilities.CompletionList(
                        itemDefaults: ["default1", "default2"]
                    )
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
                )
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
                executeCommand: nil,
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
            
            return InitializeParams(
                processId: nil,
                locale: nil,
                rootPath: nil,
                rootUri: "file://" + workspacePath,
                initializationOptions: [],
                capabilities: capabilities,
                trace: nil,
                workspaceFolders: nil
            )
        }
    }
    
    // MARK: - Document Lifecycle
    
    func openDocument(uri: String, languageId: String, text: String) async throws {
        guard !openDocuments.keys.contains(uri) else { return }
        openDocuments[uri] = 0
        
        let doc = TextDocumentItem(uri: uri, languageId: languageId, version: 0, text: text)
        try await server.textDocumentDidOpen(DidOpenTextDocumentParams(textDocument: doc))
        Self.logger.debug("Opened: \(uri)")
    }
    
    func closeDocument(uri: String) async throws {
        guard openDocuments.keys.contains(uri) else { return }
        openDocuments.removeValue(forKey: uri)
        
        try await server.textDocumentDidClose(DidCloseTextDocumentParams(textDocument: TextDocumentIdentifier(uri: uri)))
        Self.logger.debug("Closed: \(uri)")
    }
    
    func documentDidChange(uri: String, text: String) async throws {
        guard let version = openDocuments[uri] else { return }
        let newVersion = version + 1
        openDocuments[uri] = newVersion
        
        let event = TextDocumentContentChangeEvent(range: nil, rangeLength: nil, text: text)
        let params = DidChangeTextDocumentParams(
            textDocument: VersionedTextDocumentIdentifier(uri: uri, version: newVersion),
            contentChanges: [event]
        )
        try await server.textDocumentDidChange(params)
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
    
    // MARK: - Shutdown
    
    func shutdown() async throws {
        Self.logger.info("Shutting down server for \(self.languageId)")
        try await server.shutdownAndExit()
        Self.logger.info("Server shut down")
    }
}
