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
    
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "lsp.service")
    
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
    private var serverStartTask: Task<LanguageServer?, Never>?
    private var serverStartSignature: String?
    
    private var changeDebounceTimer: Timer?
    private var pendingChanges: [LanguageServer.DocumentChange] = []
    private var latestDocumentSnapshot: String?
    private var diagnosticsStabilizationDeadline: Date?
    
    var onHover: ((String?) -> Void)?
    
    init() {
        // 异步预热 LSP 配置缓存，不阻塞主线程
        // 首次 loadFile 时仍会通过 openDocument → checkAvailability(for:) 做精确检测
        Task {
            await LSPConfig.warmUpCacheInBackground()
        }
    }
    
    private(set) var _editorExtensionRegistry: EditorExtensionRegistry?

    /// 注入编辑器扩展注册中心（由 LSPServiceEditorPlugin.registerEditorExtensions 调用）
    func configureRegistry(_ registry: EditorExtensionRegistry) {
        _editorExtensionRegistry = registry
    }

    // MARK: - Debouncer (后台防抖)

    /// LSP 请求防抖器 — 避免快速连续触发导致主线程阻塞
    private let debouncer = LSPDebouncer()

    // MARK: - Availability
    
    /// 检查 LSP 可用性（使用缓存路径，不会 fork 进程）
    func checkAvailability(for languageId: String? = nil) {
        if let languageId {
            let available = LSPConfig.findServer(for: languageId) != nil
            isAvailable = available
            if Self.verbose {
                Self.logger.info("\(Self.t)LSP 可用性: \(languageId) = \(available ? "是" : "否")")
            }
            return
        }

        // 不指定语言时，只做 O(1) 的缓存查找，不再遍历所有语言 fork 进程
        // 完整扫描由 init 中的 warmUpCacheInBackground() 异步完成
        let available = LSPConfig.supportedLanguageIds.contains {
            LSPConfig.findServer(for: $0) != nil
        }
        isAvailable = available
        if Self.verbose {
            Self.logger.info("\(Self.t)LSP 可用性(任意语言) = \(available ? "是" : "否")")
        }
    }
    
    // MARK: - Server Management
    
    func startServer(for languageId: String, projectPath: String) async {
        _ = await ensureServer(for: languageId, projectPath: projectPath)
    }

    private func ensureServer(for languageId: String, projectPath: String) async -> LanguageServer? {
        if let server, activeLanguageId == languageId, projectRootPath == projectPath {
            return server
        }

        let signature = "\(languageId)|\(projectPath)"
        if let serverStartTask, serverStartSignature == signature {
            return await serverStartTask.value
        }

        if let serverStartTask {
            _ = await serverStartTask.value
        }

        let task = Task<LanguageServer?, Never> { @MainActor [weak self] in
            guard let self else { return nil }
            return await self.startServerInternal(for: languageId, projectPath: projectPath)
        }
        serverStartTask = task
        serverStartSignature = signature
        let startedServer = await task.value
        if serverStartSignature == signature {
            serverStartTask = nil
            serverStartSignature = nil
        }
        return startedServer
    }

    private func startServerInternal(for languageId: String, projectPath: String) async -> LanguageServer? {
        if let capability = Self.projectContextCapability(for: projectPath) {
            await capability.projectOpened(at: projectPath)
        }
        if let existing = server {
            if Self.verbose {
                Self.logger.info("\(Self.t)正在停止现有服务器")
            }
            try? await existing.shutdown()
            server = nil
        }
        
        guard let config = LSPConfig.defaultConfig(for: languageId) else {
            Self.logger.warning("\(Self.t)未找到 \(languageId) 的服务器配置")
            return nil
        }
        
        if Self.verbose {
            Self.logger.info("\(Self.t)启动 \(languageId) 服务器，路径: \(config.execPath)")
        }
        isInitializing = true
        activeLanguageId = languageId
        projectRootPath = projectPath
        
        let workspaceFolders = Self.makeWorkspaceFolders(for: languageId, projectPath: projectPath)
        let initializationOptions = Self.makeInitializationOptions(for: languageId, projectPath: projectPath)
        
        do {
            let newServer = try await LanguageServer.create(
                languageId: languageId,
                config: config,
                workspacePath: projectPath,
                workspaceFolders: workspaceFolders,
                initializationOptions: initializationOptions
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
                Self.logger.info("\(Self.t)\(languageId) 服务器已初始化, workspaceFolders=\(workspaceFolders?.count ?? 0), hasInitOptions=\(initializationOptions != nil)")
            }
            return newServer
        } catch {
            Self.logger.error("\(Self.t)启动服务器失败: \(error.localizedDescription)")
            isInitializing = false
            activeLanguageId = nil
            return nil
        }
    }
    
    /// 为项目型语言服务生成 workspaceFolders
    static func makeWorkspaceFolders(for languageId: String, projectPath: String) -> [LanguageServerProtocol.WorkspaceFolder]? {
        guard let capability = languageIntegrationCapability(for: languageId, projectPath: projectPath),
              let folders = capability.workspaceFolders(for: languageId, projectPath: projectPath),
              !folders.isEmpty else {
            return nil
        }
        return folders.map {
            LanguageServerProtocol.WorkspaceFolder(uri: $0.uri, name: $0.name)
        }
    }

    static func makeInitializationOptions(for languageId: String, projectPath: String) -> LanguageServerProtocol.LSPAny? {
        guard let capability = languageIntegrationCapability(for: languageId, projectPath: projectPath),
              let options = capability.initializationOptions(for: languageId, projectPath: projectPath),
              !options.isEmpty else {
            return nil
        }
        return .hash(options.reduce(into: [String: LanguageServerProtocol.LSPAny]()) { result, entry in
            result[entry.key] = .string(String(describing: entry.value))
        })
    }
    
    // MARK: - Document Lifecycle
    
    func setProjectRootPath(_ projectPath: String?) {
        projectRootPath = projectPath
        if Self.verbose {
            Self.logger.info("\(Self.t)设置项目根目录: \(projectPath ?? "<nil>", privacy: .public)")
        }
        if projectPath == nil {
            Self.projectContextCapability(for: nil)?.projectClosed()
        }
    }

    private static func projectContextCapability(for projectPath: String?) -> (any SuperEditorProjectContextCapability)? {
        LSPService.shared._editorExtensionRegistry?.projectContextCapability(for: projectPath)
    }

    private static func languageIntegrationCapability(
        for languageId: String,
        projectPath: String?
    ) -> (any SuperEditorLanguageIntegrationCapability)? {
        LSPService.shared._editorExtensionRegistry?.languageIntegrationCapability(
            for: languageId,
            projectPath: projectPath
        )
    }
    
    func openDocument(uri: String, languageId: String, text: String, version: Int = 0) async {
        checkAvailability(for: languageId)
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)openDocument: uri=\(uri, privacy: .public), languageId=\(languageId, privacy: .public), version=\(version), projectRoot=\(self.projectRootPath ?? "<nil>", privacy: .public), existingServerLanguage=\(self.activeLanguageId ?? "<nil>", privacy: .public), hasServer=\(self.server != nil)"
            )
        }

        if server == nil || activeLanguageId != languageId {
            if let root = projectRootPath {
                _ = await ensureServer(for: languageId, projectPath: root)
            } else {
                Self.logger.warning("\(Self.t)无项目根目录")
                return
            }
        }
        
        guard let server else { return }
        
        currentURI = uri
        currentVersion = version
        latestDocumentSnapshot = text
        pendingChanges.removeAll()
        currentDiagnostics = []
        
        do {
            try await server.openDocument(uri: uri, languageId: languageId, text: text, version: version)
        } catch {
            Self.logger.error("\(Self.t)打开文档失败: \(error)")
        }
    }
    
    func closeDocument(uri: String) {
        guard let server else { return }
        Task {
            do {
                try await server.closeDocument(uri: uri)
                if currentURI == uri {
                    currentURI = nil
                    currentVersion = 0
                    currentDiagnostics = []
                    latestDocumentSnapshot = nil
                    pendingChanges.removeAll()
                }
            } catch {
                Self.logger.error("\(Self.t)关闭文档失败: \(error)")
            }
        }
    }
    
    func updateDocumentSnapshot(uri: String, text: String) {
        guard uri == currentURI else { return }
        latestDocumentSnapshot = text
    }
    
    func documentDidChange(uri: String, range: LSPRange, text: String, version: Int) {
        guard uri == currentURI else { return }
        currentVersion = version
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
            try await server.documentDidChange(uri: uri, changes: changes, fullText: snapshot, version: currentVersion)
            pendingChanges.removeAll()
        } catch {
            Self.logger.error("\(Self.t)发送变更失败: \(error)")
        }
    }

    private func flushPendingChangesIfNeeded(uri: String, operation: String) async {
        guard uri == currentURI, !pendingChanges.isEmpty else { return }
        changeDebounceTimer?.invalidate()
        changeDebounceTimer = nil
        if Self.verbose {
            Self.logger.debug("\(Self.t)\(operation) 前同步待发送变更: \(self.pendingChanges.count) 条")
        }
        await flushChange(uri: uri)
    }
    
    func replaceDocument(uri: String, text: String, version: Int) {
        guard uri == currentURI else { return }
        currentVersion = version
        latestDocumentSnapshot = text
        pendingChanges.removeAll()
        changeDebounceTimer?.invalidate()
        changeDebounceTimer = nil
        guard let server else { return }
        Task {
            do {
                try await server.documentDidChange(uri: uri, text: text, version: version)
            } catch {
                Self.logger.error("\(Self.t)替换文档失败: \(error)")
            }
        }
    }

    func documentDidSave(uri: String, text: String? = nil) {
        guard uri == currentURI else { return }
        diagnosticsStabilizationDeadline = Date().addingTimeInterval(1.2)
        if let text {
            latestDocumentSnapshot = text
        }
        guard let server else { return }
        Task {
            do {
                try await server.documentDidSave(uri: uri, text: text)
            } catch {
                Self.logger.error("\(Self.t)发送 didSave 失败: \(error)")
            }
        }
    }
    
    // MARK: - LSP Features
    
    func requestCompletion(uri: String, line: Int, character: Int) async -> [CompletionItem] {
        guard let server else { return [] }
        if uri == currentURI, !self.pendingChanges.isEmpty {
            self.changeDebounceTimer?.invalidate()
            self.changeDebounceTimer = nil
            if Self.verbose {
                Self.logger.debug("\(Self.t)补全前同步待发送变更: \(self.pendingChanges.count) 条")
            }
            await self.flushChange(uri: uri)
        }
        do {
            let response: CompletionResponse = try await server.completion(uri: uri, line: line, character: character)
            return parseCompletionItems(response)
        } catch {
            Self.logger.error("\(Self.t)补全请求失败: \(error)")
            if await recoverServerIfNeeded(after: error) {
                guard let recoveredServer = self.server else { return [] }
                do {
                    let response: CompletionResponse = try await recoveredServer.completion(uri: uri, line: line, character: character)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)补全请求重试成功")
                    }
                    return parseCompletionItems(response)
                } catch {
                    Self.logger.error("\(Self.t)补全请求重试失败: \(error)")
                }
            }
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
            Self.logger.error("\(Self.t)悬停请求失败: \(error)")
            return nil
        }
    }

    /// 请求悬停提示（返回原始 Hover 对象，供调用方自行解析 Markdown）
    func requestHoverRaw(uri: String, line: Int, character: Int) async -> Hover? {
        guard let server else { return nil }
        do {
            return try await server.hover(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)原始悬停请求失败: \(error)")
            return nil
        }
    }
    
    func requestDefinition(uri: String, line: Int, character: Int) async -> Location? {
        guard let server else { return nil }
        await flushPendingChangesIfNeeded(uri: uri, operation: "definition")
        if Self.verbose {
            Self.logger.info(
                "\(Self.t)definition 请求: uri=\(uri, privacy: .public), line=\(line), character=\(character), pendingChanges=\(self.pendingChanges.count), currentURI=\(self.currentURI ?? "<nil>", privacy: .public), currentVersion=\(self.currentVersion), projectRoot=\(self.projectRootPath ?? "<nil>", privacy: .public), serverRoot=\(server.rootPath.path, privacy: .public)"
            )
        }
        do {
            let response: DefinitionResponse = try await server.definition(uri: uri, line: line, character: character)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)definition 原始响应: \(self.describeDefinitionResponse(response), privacy: .public)"
                )
            }
            let parsed = parseDefinitionLocation(response)
            if Self.verbose {
                if let parsed {
                    Self.logger.info(
                        "\(Self.t)definition 解析结果: uri=\(parsed.uri, privacy: .public), startLine=\(parsed.range.start.line), startCharacter=\(parsed.range.start.character), endLine=\(parsed.range.end.line), endCharacter=\(parsed.range.end.character)"
                    )
                } else {
                    Self.logger.warning("\(Self.t)definition 解析结果为空")
                }
            }
            return parsed
        } catch {
            Self.logger.error("\(Self.t)定义跳转失败: \(error)")
            return nil
        }
    }
    
    func requestReferences(uri: String, line: Int, character: Int) async -> [Location] {
        guard let server else { return [] }
        await flushPendingChangesIfNeeded(uri: uri, operation: "references")
        do {
            return try await server.references(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)引用查找失败: \(error)")
            return []
        }
    }

    func requestDocumentSymbols(uri: String) async -> [DocumentSymbol] {
        guard let server else { return [] }
        do {
            return try await server.documentSymbols(uri: uri)
        } catch {
            Self.logger.error("\(Self.t)文档符号请求失败: \(error)")
            return []
        }
    }

    func requestRename(uri: String, line: Int, character: Int, newName: String) async -> WorkspaceEdit? {
        guard let server else { return nil }
        await flushPendingChangesIfNeeded(uri: uri, operation: "rename")
        do {
            return try await server.rename(uri: uri, line: line, character: character, newName: newName)
        } catch {
            Self.logger.error("\(Self.t)重命名失败: \(error)")
            return nil
        }
    }

    func requestFormatting(uri: String, tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? {
        guard let server else { return nil }
        do {
            return try await server.formatting(uri: uri, tabSize: tabSize, insertSpaces: insertSpaces)
        } catch {
            Self.logger.error("\(Self.t)格式化失败: \(error)")
            return nil
        }
    }
    
    func requestSignatureHelp(uri: String, line: Int, character: Int) async -> SignatureHelp? {
        guard let server else { return nil }
        guard server.capabilities.signatureHelpProvider != nil else { return nil }
        do {
            return try await server.signatureHelp(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)签名帮助失败: \(error)")
            return nil
        }
    }
    
    func requestInlayHint(uri: String, startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? {
        guard let server else { return nil }
        guard server.capabilities.inlayHintProvider != nil else { return nil }
        do {
            return try await server.inlayHint(uri: uri, startLine: startLine, startCharacter: startCharacter, endLine: endLine, endCharacter: endCharacter)
        } catch {
            Self.logger.error("\(Self.t)内联提示失败: \(error)")
            return nil
        }
    }
    
    func requestDocumentHighlight(uri: String, line: Int, character: Int) async -> [DocumentHighlight] {
        guard let server else { return [] }
        guard server.capabilities.documentHighlightProvider != nil else { return [] }
        do {
            return try await server.documentHighlight(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)文档高亮失败: \(error)")
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
            Self.logger.error("\(Self.t)代码操作失败: \(error)")
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
            Self.logger.error("\(Self.t)代码操作解析失败: \(error.localizedDescription)")
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
            Self.logger.error("\(Self.t)语义令牌失败: \(error)")
            return nil
        }
    }
    
    func requestSemanticTokensDelta(uri: String, previousResultId: String) async -> SemanticTokensDeltaResponse? {
        guard let server else { return nil }
        do {
            return try await server.semanticTokensDelta(uri: uri, previousResultId: previousResultId)
        } catch {
            Self.logger.error("\(Self.t)语义令牌增量失败: \(error)")
            return nil
        }
    }
    
    func requestDeclaration(uri: String, line: Int, character: Int) async -> DeclarationResponse {
        guard let server else { return nil }
        guard server.capabilities.declarationProvider != nil else { return nil }
        await flushPendingChangesIfNeeded(uri: uri, operation: "declaration")
        do {
            return try await server.declaration(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)声明跳转失败: \(error)")
            return nil
        }
    }
    
    func requestTypeDefinition(uri: String, line: Int, character: Int) async -> TypeDefinitionResponse {
        guard let server else { return nil }
        guard server.capabilities.typeDefinitionProvider != nil else { return nil }
        await flushPendingChangesIfNeeded(uri: uri, operation: "typeDefinition")
        do {
            return try await server.typeDefinition(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)类型定义跳转失败: \(error)")
            return nil
        }
    }
    
    func requestImplementation(uri: String, line: Int, character: Int) async -> ImplementationResponse {
        guard let server else { return nil }
        guard server.capabilities.implementationProvider != nil else { return nil }
        await flushPendingChangesIfNeeded(uri: uri, operation: "implementation")
        do {
            return try await server.implementation(uri: uri, line: line, character: character)
        } catch {
            Self.logger.error("\(Self.t)实现查找失败: \(error)")
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
            Self.logger.error("\(Self.t)折叠范围失败: \(error)")
            return []
        }
    }
    
    // MARK: Selection Range
    
    func requestSelectionRange(uri: String, line: Int, character: Int) async -> [SelectionRange] {
        guard let server else { return [] }
        do {
            return try await server.selectionRange(uri: uri, line: line, character: character) ?? []
        } catch {
            Self.logger.error("\(Self.t)选择范围失败: \(error)")
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
            Self.logger.error("\(Self.t)文档链接失败: \(error)")
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
            Self.logger.error("\(Self.t)解析文档链接失败: \(error)")
            return nil
        }
    }
    
    func resolveDocumentLinkLSP(_ link: DocumentLink) async -> DocumentLink? {
        guard let server else { return nil }
        do {
            return try await server.resolveDocumentLink(link)
        } catch {
            Self.logger.error("\(Self.t)解析文档链接失败: \(error)")
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
            Self.logger.error("\(Self.t)文档颜色请求失败: \(error)")
            return []
        }
    }
    
    func requestColorPresentation(uri: String, red: Double, green: Double, blue: Double, alpha: Double, range: LSPRange) async -> [ColorPresentation] {
        guard let server else { return [] }
        let color = Color(red: Float(red), green: Float(green), blue: Float(blue), alpha: Float(alpha))
        do {
            return try await server.colorPresentation(uri: uri, color: color, range: range)
        } catch {
            Self.logger.error("\(Self.t)颜色展示请求失败: \(error)")
            return []
        }
    }
    
    // MARK: Call Hierarchy
    
    @discardableResult
    func requestCallHierarchyPrepare(uri: String, line: Int, character: Int) async -> [CallHierarchyItem] {
        guard let server else { return [] }
        guard server.capabilities.callHierarchyProvider != nil else { return [] }
        do {
            return try await server.callHierarchyPrepare(uri: uri, line: line, character: character) ?? []
        } catch {
            Self.logger.error("\(Self.t)调用层级准备失败: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyIncomingCalls(item: CallHierarchyItem) async -> [CallHierarchyIncomingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyIncomingCalls(item: item)) ?? []
        } catch {
            Self.logger.error("\(Self.t)调用层级(入向)失败: \(error)")
            return []
        }
    }
    
    func requestCallHierarchyOutgoingCalls(item: CallHierarchyItem) async -> [CallHierarchyOutgoingCall] {
        guard let server else { return [] }
        do {
            return (try await server.callHierarchyOutgoingCalls(item: item)) ?? []
        } catch {
            Self.logger.error("\(Self.t)调用层级(出向)失败: \(error)")
            return []
        }
    }
    
    // MARK: Workspace Symbol
    
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse {
        guard let server else { return nil }
        do {
            return try await server.workspaceSymbol(query: query)
        } catch {
            Self.logger.error("\(Self.t)工作区符号查找失败: \(error)")
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
            Self.logger.warning("\(Self.t)命令 \(command) 不在服务器能力列表中，但仍尝试执行")
        }
        do {
            return try await server.executeCommand(command: command, arguments: arguments)
        } catch {
            Self.logger.error("\(Self.t)执行命令失败: \(error)")
            return nil
        }
    }
    
    // MARK: - Progress Notifications
    
    let progressProvider = LSPProgressProvider()

    // MARK: - Recovery

    private func recoverServerIfNeeded(after error: Error) async -> Bool {
        guard isTransportClosedError(error) else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)跳过自动恢复：错误非断链类型 -> \(String(describing: error))")
            }
            return false
        }
        guard let languageId = activeLanguageId else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)跳过自动恢复：activeLanguageId 为空")
            }
            return false
        }
        guard let projectRootPath else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)跳过自动恢复：projectRootPath 为空")
            }
            return false
        }
        if Self.verbose {
            Self.logger.warning("\(Self.t)检测到 LSP 通道断开，尝试自动恢复: language=\(languageId), root=\(projectRootPath)")
        }

        _ = await ensureServer(for: languageId, projectPath: projectRootPath)
        guard let restartedServer = server else {
            Self.logger.error("\(Self.t)LSP 自动恢复失败：重启后服务器为空")
            return false
        }

        guard let currentURI, let latestDocumentSnapshot else {
            if Self.verbose {
                Self.logger.info("\(Self.t)LSP 自动恢复完成（无活跃文档）")
            }
            return true
        }

        do {
            try await restartedServer.openDocument(
                uri: currentURI,
                languageId: languageId,
                text: latestDocumentSnapshot,
                version: currentVersion
            )
            pendingChanges.removeAll()
            if Self.verbose {
                Self.logger.info("\(Self.t)LSP 自动恢复完成并重新打开文档")
            }
            return true
        } catch {
            Self.logger.error("\(Self.t)LSP 自动恢复后打开文档失败: \(error)")
            return false
        }
    }

    private func isTransportClosedError(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("datastreamclosed") ||
            description.contains("protocoltransporterror") ||
            description.contains("streamclosed")
    }
    
    // MARK: - Cleanup
    
    func stopAll() {
        if let server {
            Task { try? await server.shutdown() }
        }
        server = nil
        currentURI = nil
        currentVersion = 0
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

    private func describeDefinitionResponse(_ response: DefinitionResponse) -> String {
        guard let response else { return "nil" }
        switch response {
        case .optionA(let location):
            return "singleLocation(uri=\(location.uri), start=\(location.range.start.line):\(location.range.start.character), end=\(location.range.end.line):\(location.range.end.character))"
        case .optionB(let locations):
            let preview = locations.prefix(3).map {
                "\($0.uri)@\($0.range.start.line):\($0.range.start.character)"
            }.joined(separator: ", ")
            return "multiLocation(count=\(locations.count), preview=[\(preview)])"
        case .optionC(let links):
            let preview = links.prefix(3).map {
                "\($0.targetUri)@\($0.targetSelectionRange.start.line):\($0.targetSelectionRange.start.character)"
            }.joined(separator: ", ")
            return "locationLink(count=\(links.count), preview=[\(preview)])"
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
        if let deadline = diagnosticsStabilizationDeadline,
           Date() < deadline,
           params.diagnostics.isEmpty,
           currentDiagnostics.isEmpty == false {
            return
        }
        diagnosticsStabilizationDeadline = nil
        currentDiagnostics = params.diagnostics
    }
}
