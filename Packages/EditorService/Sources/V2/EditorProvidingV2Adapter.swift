import AppKit
import Combine
import EditorKernel
import Foundation
import KernelLumi
import LanguageServerProtocol
import SwiftUI

// MARK: - 类型消歧
//
// `EditorKernel` 中已有同名历史类型（`EditorV2Range` / `EditorV2Selection`，NSRange 语义），
// 且被本包 `@_exported import` re-export，未限定名必然解析到历史类型一侧。
// 因此本文件统一使用 KernelLumi 提供的 `EditorV2Range` / `EditorV2Selection` /
// `EditorV2CommandContext` 别名指向 V2 契约类型（zero-based UTF-16）。

// MARK: - V2 契约适配器
//
// `EditorProvidingV2Adapter` 把现有 `EditorService` 适配到 KernelLumi 编辑器契约 V2
// （`docs/editor-kernel-plugin-rearchitecture-plan.md` §30 任务 3）。
//
// 设计约束：
// - **不重写 EditorService 内部实现**，只做边界适配（§20 Phase 1）。
// - 当前运行时只有单个 Editor Group、单活动文档 Buffer；因此：
//   - 文档 revision 语义只对**活动文档**成立（`state.contentRevision`）；
//     后台 Session 的 snapshot 从磁盘读取，revision 为 0。
//   - `split` / 跨 Group 移动抛出 `capabilityUnavailable`（Phase 7 接入）。
// - 高频状态（文档、选择）不转发 Kernel 全局 `objectWillChange`；
//   消费方订阅各子能力的 `statePublisher`（CurrentValue 语义）。

/// EditorSurface 视图的注入容器。
///
/// `EditorSurfaceView` 定义在 Host 插件（依赖 EditorService），不能反向进入本包，
/// 因此 Host 在装配时把视图构造闭包注入到这里。
@MainActor
public final class EditorSurfaceBox: EditorSurfaceProviding {
    public var makeView: () -> AnyView

    public init(makeView: @escaping () -> AnyView = {
        AnyView(EmptyView())
    }) {
        self.makeView = makeView
    }

    public func makeEditorView() -> AnyView {
        makeView()
    }
}

/// `EditorProvidingV2` 的 EditorService 实现。
@MainActor
public final class EditorProvidingV2Adapter: EditorProvidingV2, EditorFeatureHostBridge {
    public let scope: EditorScope

    // 子能力持有 weak self，用 lazy 在首次访问时装配；对外以协议存在类型暴露。
    private lazy var documentCapability = DocumentCapability(adapter: self)
    private lazy var sessionCapability = SessionCapability(adapter: self)
    private lazy var selectionCapability = SelectionCapability(adapter: self)
    private lazy var navigationCapability = NavigationCapability(adapter: self, selections: selectionCapability)
    private lazy var commandCapability = CommandCapability(adapter: self)
    private lazy var configurationCapability = ConfigurationCapability()
    private lazy var diagnosticsCapability = DiagnosticsCapability(adapter: self)
    private lazy var documentSymbolCapability = DocumentSymbolCapability(adapter: self)
    private lazy var panelCapability = PanelCapability(adapter: self)
    private lazy var referencesCapability = ReferencesCapability(adapter: self)
    private lazy var callHierarchyCapability = CallHierarchyCapability(adapter: self)
    private lazy var workspaceSearchCapability = WorkspaceSearchCapability(adapter: self)

    public var documents: any EditorDocumentProviding { documentCapability }
    public var sessions: any EditorSessionProviding { sessionCapability }
    public var selections: any EditorSelectionProviding { selectionCapability }
    public var navigation: any EditorNavigationProviding { navigationCapability }
    public var commands: any EditorCommandProviding { commandCapability }
    public var configuration: any EditorConfigurationProviding { configurationCapability }
    public var diagnostics: any EditorDiagnosticsProviding { diagnosticsCapability }
    public var documentSymbols: any EditorDocumentSymbolProviding { documentSymbolCapability }
    public var panels: any EditorPanelProviding { panelCapability }
    public var references: any EditorReferencesProviding { referencesCapability }
    public var callHierarchy: any EditorCallHierarchyProviding { callHierarchyCapability }
    public var workspaceSearch: any EditorWorkspaceSearchProviding { workspaceSearchCapability }
    public let surface: any EditorSurfaceProviding

    /// Host 通过此 strongly-typed 句柄注入 Surface 视图构造闭包（与 `surface` 同一实例）。
    public let surfaceBox: EditorSurfaceBox

    /// 贡献包宿主能力（EditorContributionRegistry，Phase 4 §9）。
    public let extensions: any EditorExtensionHosting

    weak var service: EditorService?

    /// session ID → 文档 ID。当前运行时 Session 与打开的文件一一对应，
    /// 故 Session 即文档身份；未来多视图共享 Buffer 时改为 URL 级注册表。
    private var documentIDs: [EditorSession.ID: EditorDocumentID] = [:]

    public init(
        service: EditorService,
        scope: EditorScope? = nil,
        extensions: (any EditorExtensionHosting)? = nil
    ) {
        self.service = service
        self.scope = scope ?? EditorScope(windowID: .makeUnique(), workspaceID: .makeUnique())
        let surfaceBox = EditorSurfaceBox()
        self.surface = surfaceBox
        self.surfaceBox = surfaceBox
        // Host 可注入共享的 EditorContributionRegistry（legacy 回放后重放需要同一实例）。
        self.extensions = extensions ?? EditorContributionRegistry(registry: service.editorExtensionRegistry)
    }

    // MARK: - 身份映射

    func session(for documentID: EditorDocumentID) -> EditorSession? {
        guard let service else { return nil }
        for (sessionID, mappedID) in documentIDs where mappedID == documentID {
            return service.sessionStore.session(for: sessionID)
        }
        return nil
    }

    func documentID(for sessionID: EditorSession.ID) -> EditorDocumentID {
        if let existing = documentIDs[sessionID] {
            return existing
        }
        let minted = EditorDocumentID.makeUnique()
        documentIDs[sessionID] = minted
        return minted
    }

    func activeDocumentID() -> EditorDocumentID? {
        guard let service, let activeID = service.sessionStore.activeSessionID else { return nil }
        return documentID(for: activeID)
    }

    var editorService: EditorService? { service }

    // MARK: - EditorFeatureHostBridge（Phase 5 §10）

    func featureContext(languageID: String) -> EditorFeatureRequestContext {
        EditorFeatureRequestContext(
            uri: service?.files.currentFileURL,
            languageID: languageID,
            revision: service?.state.contentRevision ?? 0
        )
    }

    func open(_ location: KernelLumi.EditorLocation) {
        guard let service else { return }
        service.sessions.openFile(at: location.uri)
        // 打开后把光标落到目标位置（zero-based UTF-16 → 文本偏移）。
        let text = service.state.content?.string ?? ""
        if let offset = SelectionCapability.offset(of: location.range.start, in: text) {
            service.state.setSelections([MultiCursorSelection(location: offset, length: 0)])
        }
    }

    func apply(_ edit: KernelLumi.EditorWorkspaceEdit) {
        Task { @MainActor in
            _ = try? await documentCapability.apply(edit, expectedRevisions: [:], options: EditorEditOptions())
        }
    }

    // MARK: - 派生状态

    func activeLanguageID() -> String {
        guard let language = service?.state.detectedLanguage else { return "" }
        return language.lspLanguageId ?? language.languageId
    }

    func summary(for tab: EditorTab) -> EditorDocumentSummary {
        EditorDocumentSummary(
            id: documentID(for: tab.sessionID),
            uri: tab.fileURL ?? URL(fileURLWithPath: "/untitled-\(tab.sessionID.uuidString)"),
            languageID: isActiveSession(tab.sessionID) ? activeLanguageID() : "",
            revision: isActiveSession(tab.sessionID) ? (service?.state.contentRevision ?? 0) : 0,
            isDirty: tab.isDirty,
            isReadOnly: isActiveSession(tab.sessionID) && !(service?.state.isEditable ?? true),
            largeFileMode: isActiveSession(tab.sessionID) ? mappedLargeFileMode() : .normal
        )
    }

    func isActiveSession(_ sessionID: EditorSession.ID) -> Bool {
        service?.sessionStore.activeSessionID == sessionID
    }

    private func mappedLargeFileMode() -> EditorLargeFileMode {
        guard let service else { return .normal }
        if service.files.isBinaryFile || service.files.isTruncated {
            return .readOnly
        }
        switch service.files.largeFileMode {
        case .normal:
            return .normal
        case .medium, .large:
            return .degraded
        case .mega:
            return .readOnly
        }
    }

    /// 等待当前文件加载完成（open/load 是异步触发、同步返回）。
    func waitForFileLoad(timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while service?.state.isFileLoadInProgress == true && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// 等待保存完成（save 触发的写盘在 Save Workflow 内异步执行）。
    func waitForSaveToSettle(timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while service?.files.hasUnsavedChanges == true && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

// MARK: - 文档能力

@MainActor
private final class DocumentCapability: EditorDocumentProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorDocumentState, Never>

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(DocumentCapability.computeState(from: adapter))
        // objectWillChange 发出时尚未落盘新值，经一次 MainActor hop 后再采样。
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeState(from: adapter))
    }

    private static func computeState(from adapter: EditorProvidingV2Adapter) -> EditorDocumentState {
        guard let service = adapter.service else {
            return EditorDocumentState(activeDocument: nil, documents: [])
        }
        let summaries = service.sessionStore.tabs.map { adapter.summary(for: $0) }
        let active = service.sessionStore.activeSessionID.flatMap { activeID in
            summaries.first { $0.id == adapter.documentID(for: activeID) }
        }
        return EditorDocumentState(activeDocument: active, documents: summaries)
    }

    var activeDocument: EditorDocumentSummary? {
        adapter.flatMap { Self.computeState(from: $0).activeDocument }
    }

    var statePublisher: AnyPublisher<EditorDocumentState, Never> {
        subject.eraseToAnyPublisher()
    }

    func snapshot(documentID: EditorDocumentID) async throws -> EditorDocumentSnapshot {
        guard let adapter, let service = adapter.service else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents")
        }
        guard let session = adapter.session(for: documentID), let url = session.fileURL else {
            throw EditorContractError.documentNotFound(documentID)
        }

        // 活动文档：从运行时状态读取完整文本与 revision。
        if adapter.isActiveSession(session.id), service.state.currentFileURL == url {
            return EditorDocumentSnapshot(
                id: documentID,
                uri: url,
                languageID: adapter.activeLanguageID(),
                revision: service.state.contentRevision,
                text: service.state.content?.string ?? "",
                isDirty: service.files.hasUnsavedChanges,
                isReadOnly: !service.state.isEditable,
                largeFileMode: .normal
            )
        }

        // 后台 Session：从磁盘读取；revision 语义只对活动文档成立（见类型注释）。
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let tab = service.sessionStore.tabs.first { $0.sessionID == session.id }
        return EditorDocumentSnapshot(
            id: documentID,
            uri: url,
            languageID: "",
            revision: 0,
            text: text,
            isDirty: tab?.isDirty ?? false,
            isReadOnly: false,
            largeFileMode: .normal
        )
    }

    func open(_ request: EditorOpenRequest) async throws -> EditorSessionID {
        guard let adapter, let service = adapter.service else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents")
        }
        switch request.kind {
        case .activate, .preview:
            // 预览标签复用（preview tab）由 Phase 3 Session 重构接入，暂按常规打开。
            // 用 `open(at:)`（触发内容加载）；openFile(at:) 只建 pending session。
            service.sessions.open(at: request.uri)
            await adapter.waitForFileLoad()
            let standardized = request.uri.standardizedFileURL
            guard let session = service.sessionStore.sessions.first(where: {
                $0.fileURL?.standardizedFileURL == standardized
            }) else {
                throw EditorContractError.capabilityUnavailable(feature: "editor.documents.open")
            }
            return EditorSessionID(rawValue: session.id)
        case .background:
            let session = service.sessions.openFileSessionInBackground(at: request.uri)
            return EditorSessionID(rawValue: session.id)
        }
    }

    func save(documentID: EditorDocumentID, reason: EditorSaveReason) async throws {
        guard let adapter, let service = adapter.service,
              adapter.activeDocumentID() == documentID else {
            // 后台 Session 的保存由 Phase 3 会话级保存管线接入。
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents.save")
        }
        switch reason {
        case .auto:
            service.files.triggerAutoSave(reason: "kernel_v2")
        case .explicit, .afterEdit, .beforeClose:
            service.files.saveNow()
        }
        await adapter.waitForSaveToSettle()
    }

    func saveAll(reason: EditorSaveReason) async throws {
        guard let adapter, let service = adapter.service else { return }
        guard service.files.hasUnsavedChanges else { return }
        if reason == .auto {
            service.files.triggerAutoSave(reason: "kernel_v2_save_all")
        } else {
            service.files.saveNow()
        }
        await adapter.waitForSaveToSettle()
    }

    func revert(documentID: EditorDocumentID) async throws {
        try reloadFromDisk(documentID: documentID)
    }

    func reload(documentID: EditorDocumentID) async throws {
        try reloadFromDisk(documentID: documentID)
    }

    private func reloadFromDisk(documentID: EditorDocumentID) throws {
        guard let adapter, let service = adapter.service,
              let session = adapter.session(for: documentID), let url = session.fileURL else {
            throw EditorContractError.documentNotFound(documentID)
        }
        guard adapter.isActiveSession(session.id) else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents.reload")
        }
        service.files.loadFile(from: url)
    }

    func loadFullDocument(documentID: EditorDocumentID) async throws {
        guard let adapter, let service = adapter.service,
              adapter.activeDocumentID() == documentID else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents.loadFullDocument")
        }
        service.files.loadFullFile()
    }

    func apply(
        _ edit: EditorWorkspaceEdit,
        expectedRevisions: [EditorDocumentID: UInt64],
        options: EditorEditOptions
    ) async throws -> EditorWorkspaceEditResult {
        guard let adapter, let service = adapter.service else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.documents.apply")
        }
        guard edit.hasOverlappingEdits == false else {
            throw EditorContractError.invalidWorkspaceEdit(reason: "overlapping edits")
        }

        var applied: [EditorDocumentID] = []
        var failures: [EditorDocumentID: EditorContractError] = [:]

        for documentEdit in edit.documentEdits where documentEdit.edits.isEmpty == false {
            let documentID = documentEdit.documentID
            do {
                try applyDocumentEdit(
                    documentEdit,
                    expectedRevision: expectedRevisions[documentID],
                    options: options
                )
                applied.append(documentID)
            } catch {
                failures[documentID] = error as? EditorContractError
                    ?? .providerFailed(providerID: "editor.host", reason: "\(error)")
            }
        }

        for operation in edit.fileOperations {
            let documentID = EditorDocumentID.makeUnique()
            do {
                try await applyFileOperation(operation)
                // 文件操作没有对应已打开文档；只在失败时体现在结果里。
                _ = documentID
            } catch {
                failures[documentID] = .providerFailed(providerID: "editor.host", reason: "\(error)")
            }
        }

        if options.saveAfterApplying, service.files.hasUnsavedChanges {
            service.files.saveNow()
            await adapter.waitForSaveToSettle()
        }

        return EditorWorkspaceEditResult(appliedDocumentIDs: applied, failures: failures)
    }

    private func applyDocumentEdit(
        _ documentEdit: EditorDocumentEdit,
        expectedRevision: UInt64?,
        options: EditorEditOptions
    ) throws {
        guard let adapter, let service = adapter.service,
              let session = adapter.session(for: documentEdit.documentID),
              let url = session.fileURL else {
            throw EditorContractError.documentNotFound(documentEdit.documentID)
        }

        let lspEdits = documentEdit.edits.map { edit in
            TextEdit(
                range: LSPRange(
                    start: Position(line: edit.range.start.line, character: edit.range.start.character),
                    end: Position(line: edit.range.end.line, character: edit.range.end.character)
                ),
                newText: edit.newText
            )
        }

        let isActive = adapter.isActiveSession(session.id) && service.state.currentFileURL == url
        if isActive {
            // revision 校验只对活动文档成立。
            if let expectedRevision, service.state.contentRevision != expectedRevision {
                throw EditorContractError.revisionMismatch(
                    documentID: documentEdit.documentID,
                    expected: expectedRevision,
                    actual: service.state.contentRevision
                )
            }
            if service.files.hasUnsavedChanges == false && service.state.isEditable == false {
                throw EditorContractError.readOnlyDocument(documentEdit.documentID)
            }
            let reason = options.label.isEmpty ? "kernel_v2_edit" : options.label
            service.state.applyTextEditsToCurrentDocument(lspEdits, reason: reason)
        } else {
            let ok = service.state.applyTextEditsToFile(lspEdits, url: url)
            if !ok {
                throw EditorContractError.providerFailed(
                    providerID: "editor.host",
                    reason: "failed to apply edits to \(url.path)"
                )
            }
        }
    }

    private func applyFileOperation(_ operation: EditorFileOperation) async throws {
        let executor = WorkspaceEditFileOperationsExecutor.shared
        let uri = operation.uri.absoluteString
        switch operation.kind {
        case .create:
            _ = await executor.applyCreateFile(uri: uri, overwrite: false, ignoreIfExists: true)
        case .rename(let to):
            _ = await executor.applyRenameFile(
                oldURI: uri,
                newURI: to.absoluteString,
                overwrite: false,
                ignoreIfExists: false
            )
        case .delete:
            _ = await executor.applyDeleteFile(uri: uri, recursive: true, ignoreIfNotExists: true)
        }
    }
}

// MARK: - Session 能力

@MainActor
private final class SessionCapability: EditorSessionProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorWorkbenchState, Never>
    private var cancellables = Set<AnyCancellable>()
    /// 当前运行时只有单 Group；Group ID 由 Host 生成并保持稳定。
    private let groupID = EditorGroupID.makeUnique()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(SessionCapability.computeState(from: adapter, groupID: groupID))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeState(from: adapter, groupID: groupID))
    }

    private static func computeState(
        from adapter: EditorProvidingV2Adapter,
        groupID: EditorGroupID
    ) -> EditorWorkbenchState {
        guard let service = adapter.service else {
            return EditorWorkbenchState(groups: [], activeGroupID: nil)
        }
        let tabs = service.sessionStore.tabs.map { tab in
            EditorSessionTab(
                id: EditorSessionID(rawValue: tab.sessionID),
                documentID: adapter.documentID(for: tab.sessionID),
                uri: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                isPreview: tab.isPreview
            )
        }
        let group = EditorGroupState(
            id: groupID,
            tabs: tabs,
            activeSessionID: service.sessionStore.activeSessionID.map(EditorSessionID.init(rawValue:))
        )
        return EditorWorkbenchState(groups: [group], activeGroupID: groupID)
    }

    var state: EditorWorkbenchState {
        guard let adapter else {
            return EditorWorkbenchState(groups: [], activeGroupID: nil)
        }
        return Self.computeState(from: adapter, groupID: groupID)
    }

    var statePublisher: AnyPublisher<EditorWorkbenchState, Never> {
        subject.eraseToAnyPublisher()
    }

    func activate(sessionID: EditorSessionID) {
        adapter?.service?.sessions.activateAndRestoreSession(id: sessionID.rawValue)
    }

    func close(sessionID: EditorSessionID, policy: EditorClosePolicy) async throws {
        guard let service = adapter?.service else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.sessions")
        }
        let tab = service.sessionStore.tabs.first { $0.sessionID == sessionID.rawValue }
        if tab?.isDirty == true {
            switch policy {
            case .requireConfirmation:
                throw EditorContractError.closeRequiresConfirmation(sessionID)
            case .saveFirst:
                if let activeID = service.sessionStore.activeSessionID,
                   activeID == sessionID.rawValue {
                    service.files.saveNow()
                    await adapter?.waitForSaveToSettle()
                }
            case .discardChanges:
                break
            }
        }
        service.sessions.closeSession(id: sessionID.rawValue)
    }

    func closeOthers(keeping sessionID: EditorSessionID) async throws {
        adapter?.service?.sessions.closeOtherSessions(keeping: sessionID.rawValue)
    }

    func closeToLeft(of sessionID: EditorSessionID) async throws {
        adapter?.service?.sessions.closeTabsToLeft(of: sessionID.rawValue)
    }

    func closeToRight(of sessionID: EditorSessionID) async throws {
        adapter?.service?.sessions.closeTabsToRight(of: sessionID.rawValue)
    }

    func setPinned(_ pinned: Bool, sessionID: EditorSessionID) {
        guard let service = adapter?.service,
              let tab = service.sessionStore.tabs.first(where: { $0.sessionID == sessionID.rawValue }),
              tab.isPinned != pinned else { return }
        service.sessions.togglePinned(sessionID: sessionID.rawValue)
    }

    func move(sessionID: EditorSessionID, before: EditorSessionID?, in groupID: EditorGroupID) {
        guard groupID == self.groupID else {
            return
        }
        adapter?.service?.sessions.reorderSession(
            sessionID: sessionID.rawValue,
            before: before?.rawValue
        )
    }

    func split(sessionID: EditorSessionID, direction: EditorSplitDirection) -> EditorGroupID {
        // 多 Group/Split 由 Phase 7 接入；契约先声明能力形态。
        // 协议不支持抛错，这里返回当前 Group 并保持单 Group 不变。
        _ = sessionID
        _ = direction
        return groupID
    }

    func move(sessionID: EditorSessionID, to groupID: EditorGroupID) {
        // 单 Group 运行时下跨 Group 移动为 no-op。
        _ = sessionID
        _ = groupID
    }

    func navigateBack() {
        _ = adapter?.service?.sessions.goBack()
    }

    func navigateForward() {
        _ = adapter?.service?.sessions.goForward()
    }
}

// MARK: - 选择能力

@MainActor
private final class SelectionCapability: EditorSelectionProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorSelectionSnapshot, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(SelectionCapability.computeSnapshot(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeSnapshot(from: adapter))
    }

    private static func computeSnapshot(from adapter: EditorProvidingV2Adapter) -> EditorSelectionSnapshot {
        guard let service = adapter.service else {
            return EditorSelectionSnapshot(selections: [], documentID: .makeUnique(), revision: 0)
        }
        let text = service.state.content?.string ?? ""
        let ranges = service.state.currentSelectionsAsNSRanges()
        let selections = ranges.compactMap { range -> EditorV2Selection? in
            guard let start = Self.position(utf16Offset: Int(range.location), in: text),
                  let end = Self.position(utf16Offset: Int(range.location + range.length), in: text) else {
                return nil
            }
            return EditorV2Selection(anchor: start, active: end)
        }
        return EditorSelectionSnapshot(
            selections: selections,
            documentID: adapter.activeDocumentID() ?? .makeUnique(),
            revision: service.state.contentRevision
        )
    }

    var snapshot: EditorSelectionSnapshot {
        guard let adapter else {
            return EditorSelectionSnapshot(selections: [], documentID: .makeUnique(), revision: 0)
        }
        return Self.computeSnapshot(from: adapter)
    }

    var statePublisher: AnyPublisher<EditorSelectionSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    func setSelections(_ selections: [EditorV2Selection], reveal: EditorRevealPolicy) {
        guard let service = adapter?.service else { return }
        let text = service.state.content?.string ?? ""
        let nsSelections = selections.compactMap { selection -> MultiCursorSelection? in
            guard let start = Self.offset(of: selection.range.start, in: text),
                  let end = Self.offset(of: selection.range.end, in: text) else { return nil }
            return MultiCursorSelection(location: start, length: end - start)
        }
        service.state.setSelections(nsSelections)
    }

    func selectedText() async -> String? {
        guard let service = adapter?.service,
              let text = service.state.content?.string,
              let range = service.state.currentSelectionsAsNSRanges().first,
              range.length > 0,
              let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    func addCursor(at position: EditorPosition) {
        guard let service = adapter?.service else { return }
        let text = service.state.content?.string ?? ""
        guard let offset = Self.offset(of: position, in: text) else { return }
        var selections = service.state.currentSelectionsAsNSRanges().map {
            MultiCursorSelection(location: Int($0.location), length: Int($0.length))
        }
        selections.append(MultiCursorSelection(location: offset, length: 0))
        service.state.setSelections(selections)
    }

    func addNextOccurrence() {
        adapter?.service?.state.addNextOccurrence()
    }

    func addAllOccurrences() {
        guard let service = adapter?.service,
              let text = service.state.content?.string,
              let primary = service.state.currentSelectionsAsNSRanges().first,
              primary.length > 0,
              let swiftRange = Range(primary, in: text) else { return }
        let needle = String(text[swiftRange])
        var selections: [MultiCursorSelection] = []
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: needle, range: searchRange) {
            selections.append(MultiCursorSelection(
                location: text.utf16.distance(from: text.startIndex, to: found.lowerBound),
                length: needle.utf16.count
            ))
            searchRange = found.upperBound..<text.endIndex
        }
        guard selections.isEmpty == false else { return }
        service.state.setSelections(selections)
    }

    func clearSecondaryCursors() {
        adapter?.service?.state.clearMultiCursors()
    }

    // MARK: UTF-16 换算（与 V2 契约的 zero-based UTF-16 语义一致）

    /// 每行起点的 UTF-16 偏移（按 `\n` 切行；`lines[0] == 0`）。
    private static func lineStartOffsets(of text: String) -> [Int] {
        var offsets = [0]
        var consumed = 0
        for character in text {
            consumed += character.utf16.count
            if character == "\n" {
                offsets.append(consumed)
            }
        }
        return offsets
    }

    static func offset(of position: EditorPosition, in text: String) -> Int? {
        let starts = Self.lineStartOffsets(of: text)
        guard position.line >= 0, position.line < starts.count else { return nil }
        let lineStart = starts[position.line]
        let lineEnd = position.line + 1 < starts.count
            ? starts[position.line + 1] - 1  // 减去行尾 "\n" 的 1 个 code unit
            : text.utf16.count
        guard position.character >= 0, position.character <= lineEnd - lineStart else { return nil }
        return lineStart + position.character
    }

    private static func position(utf16Offset: Int, in text: String) -> EditorPosition? {
        let starts = Self.lineStartOffsets(of: text)
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }
        var line = 0
        for (index, lineStart) in starts.enumerated() where lineStart <= utf16Offset {
            line = index
        }
        return EditorPosition(line: line, character: utf16Offset - starts[line])
    }
}

// MARK: - 导航能力

@MainActor
private final class NavigationCapability: EditorNavigationProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let selections: SelectionCapability

    init(adapter: EditorProvidingV2Adapter, selections: SelectionCapability) {
        self.adapter = adapter
        self.selections = selections
    }

    func open(_ location: EditorLocation, options: EditorOpenOptions) {
        guard let service = adapter?.service else { return }
        switch options.focus {
        case .activate, .preview:
            service.sessions.open(at: location.uri)
        case .keepCurrent:
            service.sessions.openFileSessionInBackground(at: location.uri)
        }
        // 打开后把光标落到目标位置（Phase 1 导航语义：open + reveal）。
        selections.setSelections(
            [EditorV2Selection(at: location.range.start)],
            reveal: options.reveal
        )
    }

    func reveal(_ range: EditorV2Range, in documentID: EditorDocumentID) {
        guard let adapter, let service = adapter.service else { return }
        if adapter.activeDocumentID() != documentID,
           let session = adapter.session(for: documentID), let url = session.fileURL {
            service.sessions.open(at: url)
        }
        selections.setSelections([EditorV2Selection(anchor: range.start, active: range.end)], reveal: .minimal)
    }

    func peek(_ locations: [EditorLocation], origin: EditorLocation?) {
        // Peek UI 由 Phase 5 标准语言 Overlay 接入。
    }

    func goBack() {
        _ = adapter?.service?.sessions.goBack()
    }

    func goForward() {
        _ = adapter?.service?.sessions.goForward()
    }
}

// MARK: - 命令能力

@MainActor
private final class CommandCapability: EditorCommandProviding {
    private weak var adapter: EditorProvidingV2Adapter?

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
    }

    func execute(_ id: EditorCommandID, arguments: [EditorCommandArgument]) async throws {
        guard let service = adapter?.service else {
            throw EditorContractError.capabilityUnavailable(feature: "editor.commands")
        }
        // Phase 1 参数化命令未开放；命令面板/菜单继续走内部带上下文的调用路径。
        service.commands.performCommand(id: id.rawValue)
    }

    func presentation(
        matching query: String,
        context: EditorV2CommandContext
    ) -> EditorCommandPresentation {
        guard let suggestion = matchedSuggestion(matching: query) else {
            return EditorCommandPresentation(id: EditorCommandID(rawValue: query), title: query, isEnabled: false)
        }
        return EditorCommandPresentation(
            id: EditorCommandID(rawValue: suggestion.id),
            title: suggestion.title,
            category: suggestion.category ?? "",
            isEnabled: suggestion.isEnabled,
            keybindingLabel: suggestion.shortcut?.displayText
        )
    }

    func keybinding(for commandID: EditorCommandID, context: EditorV2CommandContext) -> EditorKeybinding? {
        guard let suggestion = adapter?.service?.commands.commandSuggestions().first(where: { $0.id == commandID.rawValue }),
              let shortcut = suggestion.shortcut else { return nil }
        return EditorKeybinding(chords: [shortcut.displayText])
    }

    private func matchedSuggestion(matching query: String) -> EditorCommandSuggestion? {
        let suggestions = adapter?.service?.commands.commandSuggestions() ?? []
        if query.isEmpty { return suggestions.first }
        return suggestions.first { $0.id == query }
            ?? suggestions.first { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - 配置能力

/// Phase 1 最小配置实现。
///
/// 现有 `EditorConfigController` 是类型化快照（fontSize/tabWidth/...），
/// 不是分作用域键值模型；完整的 scope 解析与插件 schema 贡献随
/// `editor.contributions.v2` 阶段接入。
@MainActor
private final class ConfigurationCapability: EditorConfigurationProviding {
    private let subject = CurrentValueSubject<EditorConfigurationSnapshot, Never>(EditorConfigurationSnapshot())

    var snapshot: EditorConfigurationSnapshot { subject.value }

    var statePublisher: AnyPublisher<EditorConfigurationSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    func resolvedValue(for key: EditorSettingKey, context: EditorConfigurationContext) -> EditorSettingValue? {
        snapshot.rawValue(for: key, context: context)
    }

    func update(_ value: EditorSettingValue?, for key: EditorSettingKey, scope: EditorSettingScope) throws {
        throw EditorContractError.capabilityUnavailable(feature: "editor.configuration")
    }
}

// MARK: - 诊断能力

/// 诊断数据面：映射 `panelState.problemDiagnostics`（LSP `Diagnostic`）到契约快照。
///
/// 当前诊断按活动文档聚合（LSPService 只为当前 URI 发布诊断）；
/// documentURI 取活动文档 URL。
@MainActor
private final class DiagnosticsCapability: EditorDiagnosticsProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorDiagnosticsSnapshot, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(Self.computeSnapshot(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeSnapshot(from: adapter))
    }

    private static func computeSnapshot(from adapter: EditorProvidingV2Adapter) -> EditorDiagnosticsSnapshot {
        guard let service = adapter.service else { return .empty }
        let uri = service.files.currentFileURL
            ?? URL(fileURLWithPath: "/untitled")
        let items = service.panel.panelState.problemDiagnostics.map { diagnostic in
            EditorDiagnosticItem(
                id: Self.makeID(uri: uri, diagnostic: diagnostic),
                documentURI: uri,
                range: Self.mapRange(diagnostic.range),
                severity: Self.mapSeverity(diagnostic.severity),
                message: diagnostic.message,
                source: diagnostic.source,
                code: diagnostic.code.map { "\($0)" }
            )
        }
        return EditorDiagnosticsSnapshot(diagnostics: items)
    }

    var snapshot: EditorDiagnosticsSnapshot {
        guard let adapter else { return .empty }
        return Self.computeSnapshot(from: adapter)
    }

    var statePublisher: AnyPublisher<EditorDiagnosticsSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    private static func makeID(uri: URL, diagnostic: Diagnostic) -> String {
        let range = diagnostic.range
        return [
            uri.path,
            "\(range.start.line)-\(range.start.character)",
            "\(range.end.line)-\(range.end.character)",
            String(describing: diagnostic.severity),
            diagnostic.message,
        ].joined(separator: "#")
    }

    private static func mapRange(_ range: LSPRange) -> EditorV2Range {
        EditorV2Range(
            start: EditorPosition(line: Int(range.start.line), character: Int(range.start.character)),
            end: EditorPosition(line: Int(range.end.line), character: Int(range.end.character))
        )
    }

    private static func mapSeverity(_ severity: DiagnosticSeverity?) -> EditorDiagnosticSeverity {
        switch severity {
        case .error: return .error
        case .warning: return .warning
        case .information: return .information
        case .hint, .none: return .hint
        }
    }
}

// MARK: - 文档符号能力

/// 文档符号数据面：映射 `documentSymbolProvider`（`EditorDocumentSymbolItem`，LSP 语义）到契约符号树。
@MainActor
private final class DocumentSymbolCapability: EditorDocumentSymbolProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorDocumentSymbolsState, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(Self.computeState(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.resample()
                }
            }
            .store(in: &cancellables)
    }

    private func resample() {
        guard let adapter else { return }
        subject.send(Self.computeState(from: adapter))
    }

    private static func computeState(from adapter: EditorProvidingV2Adapter) -> EditorDocumentSymbolsState {
        guard let provider = adapter.service?.editorExtensionRegistry.documentSymbolProvider else {
            return .empty
        }
        return EditorDocumentSymbolsState(
            symbols: provider.symbols.map(Self.mapSymbol),
            isLoading: provider.isLoading
        )
    }

    var activeSymbols: [EditorDocumentSymbol] {
        subject.value.symbols
    }

    var isLoading: Bool { subject.value.isLoading }

    var statePublisher: AnyPublisher<EditorDocumentSymbolsState, Never> {
        subject.eraseToAnyPublisher()
    }

    func refresh() {
        adapter?.service?.editorExtensionRegistry.documentSymbolProvider?.refresh()
    }

    private static func mapSymbol(_ item: EditorDocumentSymbolItem) -> EditorDocumentSymbol {
        EditorDocumentSymbol(
            id: item.id,
            name: item.name,
            detail: item.detail,
            kind: EditorDocumentSymbolKind(lspRawValue: Int(item.kind.rawValue)),
            range: mapRange(item.range),
            selectionRange: mapRange(item.selectionRange),
            children: item.children.map(mapSymbol)
        )
    }

    private static func mapRange(_ range: LSPRange) -> EditorV2Range {
        EditorV2Range(
            start: EditorPosition(line: Int(range.start.line), character: Int(range.start.character)),
            end: EditorPosition(line: Int(range.end.line), character: Int(range.end.character))
        )
    }
}

// MARK: - 面板能力

/// 底部面板控制：映射 `EditorPanelState` 的展示标志与 `EditorPanelService.presentBottomPanel`。
@MainActor
private final class PanelCapability: EditorPanelProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorBottomPanel?, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(Self.computePanel(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computePanel(from: adapter))
    }

    private static func computePanel(from adapter: EditorProvidingV2Adapter) -> EditorBottomPanel? {
        guard let active = adapter.service?.panel.panelState.activeBottomPanel else { return nil }
        return Self.mapKind(active)
    }

    var bottomPanel: EditorBottomPanel? {
        guard let adapter else { return nil }
        return Self.computePanel(from: adapter)
    }

    var statePublisher: AnyPublisher<EditorBottomPanel?, Never> {
        subject.eraseToAnyPublisher()
    }

    func presentBottomPanel(_ panel: EditorBottomPanel?) {
        guard let service = adapter?.service else { return }
        service.panel.presentBottomPanel(panel.map(Self.mapPanel))
    }

    private static func mapKind(_ kind: EditorBottomPanelKind) -> EditorBottomPanel {
        switch kind {
        case .problems: return .problems
        case .references: return .references
        case .searchResults: return .searchResults
        case .workspaceSymbols: return .workspaceSymbols
        case .callHierarchy: return .callHierarchy
        }
    }

    private static func mapPanel(_ panel: EditorBottomPanel) -> EditorBottomPanelKind {
        switch panel {
        case .problems: return .problems
        case .references: return .references
        case .searchResults: return .searchResults
        case .workspaceSymbols: return .workspaceSymbols
        case .callHierarchy: return .callHierarchy
        }
    }
}

// MARK: - 引用能力

/// 引用数据面：映射 `panelState.referenceResults` / `selectedReferenceResult`。
@MainActor
private final class ReferencesCapability: EditorReferencesProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorReferencesState, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(Self.computeState(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeState(from: adapter))
    }

    private static func computeState(from adapter: EditorProvidingV2Adapter) -> EditorReferencesState {
        guard let panelState = adapter.service?.panel.panelState else { return .empty }
        return EditorReferencesState(
            results: panelState.referenceResults.map(Self.mapItem),
            selected: panelState.selectedReferenceResult.map(Self.mapItem)
        )
    }

    var references: EditorReferencesState {
        guard let adapter else { return .empty }
        return Self.computeState(from: adapter)
    }

    var statePublisher: AnyPublisher<EditorReferencesState, Never> {
        subject.eraseToAnyPublisher()
    }

    private static func mapItem(_ item: EditorReferenceResult) -> EditorReferenceItem {
        EditorReferenceItem(
            uri: item.url,
            line: item.line,
            column: item.column,
            path: item.path,
            preview: item.preview
        )
    }
}

// MARK: - 调用层级能力

/// 调用层级数据面：映射 `callHierarchyProvider`。
///
/// LSP `CallHierarchyItem.data` 等宿主细节不进入契约；
/// 节点 ID → 宿主 item 的映射由本适配器维护。
@MainActor
private final class CallHierarchyCapability: EditorCallHierarchyProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorCallHierarchyState, Never>
    private var cancellables = Set<AnyCancellable>()
    /// 契约节点 ID → 宿主 `EditorCallHierarchyItem`（含 LSP data）。
    private var hostItemsByID: [UUID: EditorCallHierarchyItem] = [:]

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(.empty)
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let provider = adapter?.service?.editorExtensionRegistry.callHierarchyProvider else {
            return
        }
        let state = EditorCallHierarchyState(
            root: provider.rootItem.map(Self.mapNode),
            incoming: provider.incomingCalls.map { Self.mapEdge($0, cache: &hostItemsByID) },
            outgoing: provider.outgoingCalls.map { Self.mapEdge($0, cache: &hostItemsByID) },
            isLoading: provider.isLoading
        )
        subject.send(state)
    }

    var hierarchy: EditorCallHierarchyState { subject.value }

    var statePublisher: AnyPublisher<EditorCallHierarchyState, Never> {
        subject.eraseToAnyPublisher()
    }

    func prepare(uri: URL, position: EditorPosition) {
        guard let provider = adapter?.service?.editorExtensionRegistry.callHierarchyProvider else { return }
        Task { @MainActor in
            await provider.prepareCallHierarchy(
                uri: uri.absoluteString,
                line: position.line,
                character: position.character
            )
        }
    }

    func fetchIncomingCalls(node: EditorCallHierarchyNode) {
        guard let provider = adapter?.service?.editorExtensionRegistry.callHierarchyProvider,
              let item = hostItemsByID[node.id] ?? hostItem(for: node) else { return }
        Task { @MainActor in
            await provider.fetchIncomingCalls(item: item)
        }
    }

    func fetchOutgoingCalls(node: EditorCallHierarchyNode) {
        guard let provider = adapter?.service?.editorExtensionRegistry.callHierarchyProvider,
              let item = hostItemsByID[node.id] ?? hostItem(for: node) else { return }
        Task { @MainActor in
            await provider.fetchOutgoingCalls(item: item)
        }
    }

    func clear() {
        hostItemsByID.removeAll()
        adapter?.service?.editorExtensionRegistry.callHierarchyProvider?.clear()
    }

    /// 节点没有缓存时，从 provider 根节点回查宿主 item（根节点未经 mapEdge 缓存，
    /// 直接对根节点 fetch incoming/outgoing 时需要此回退）。
    private func hostItem(for node: EditorCallHierarchyNode) -> EditorCallHierarchyItem? {
        guard let root = adapter?.service?.editorExtensionRegistry.callHierarchyProvider?.rootItem,
              root.id == node.id
        else { return nil }
        return root
    }

    private static func mapNode(_ item: EditorCallHierarchyItem) -> EditorCallHierarchyNode {
        EditorCallHierarchyNode(
            id: item.id,
            name: item.name,
            kind: EditorDocumentSymbolKind(lspRawValue: Int(item.kind.rawValue)),
            uri: URL(string: item.uri) ?? URL(fileURLWithPath: item.uri),
            range: mapRange(item.range),
            selectionRange: mapRange(item.selectionRange)
        )
    }

    private static func mapEdge(
        _ call: EditorCallHierarchyCall,
        cache: inout [UUID: EditorCallHierarchyItem]
    ) -> EditorCallHierarchyEdge {
        cache[call.item.id] = call.item
        return EditorCallHierarchyEdge(
            node: mapNode(call.item),
            callRanges: call.fromRanges.map(mapRange)
        )
    }

    private static func mapRange(_ range: LSPRange) -> EditorV2Range {
        EditorV2Range(
            start: EditorPosition(line: Int(range.start.line), character: Int(range.start.character)),
            end: EditorPosition(line: Int(range.end.line), character: Int(range.end.character))
        )
    }
}

// MARK: - 工作区搜索能力

/// 工作区搜索数据面：映射 `panelState` 搜索字段与 `EditorPanelService` 搜索操作。
///
/// 折叠/选中态属于视图局部状态，由插件自持。
@MainActor
private final class WorkspaceSearchCapability: EditorWorkspaceSearchProviding {
    private weak var adapter: EditorProvidingV2Adapter?
    private let subject: CurrentValueSubject<EditorWorkspaceSearchState, Never>
    private var cancellables = Set<AnyCancellable>()

    init(adapter: EditorProvidingV2Adapter) {
        self.adapter = adapter
        self.subject = CurrentValueSubject(Self.computeState(from: adapter))
        adapter.service?.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let adapter else { return }
        subject.send(Self.computeState(from: adapter))
    }

    private static func computeState(from adapter: EditorProvidingV2Adapter) -> EditorWorkspaceSearchState {
        guard let panelState = adapter.service?.panel.panelState else { return .empty }
        return EditorWorkspaceSearchState(
            results: panelState.workspaceSearchResults.map { result in
                EditorSearchFileResult(
                    uri: result.url,
                    path: result.path,
                    matches: result.matches.map(Self.mapMatch)
                )
            },
            summary: panelState.workspaceSearchSummary.map { summary in
                EditorSearchSummary(
                    query: summary.query,
                    totalMatches: summary.totalMatches,
                    totalFiles: summary.totalFiles
                )
            },
            errorMessage: panelState.workspaceSearchErrorMessage,
            isLoading: panelState.isWorkspaceSearchLoading
        )
    }

    var search: EditorWorkspaceSearchState {
        guard let adapter else { return .empty }
        return Self.computeState(from: adapter)
    }

    var statePublisher: AnyPublisher<EditorWorkspaceSearchState, Never> {
        subject.eraseToAnyPublisher()
    }

    func performSearch(_ query: String) {
        guard let service = adapter?.service else { return }
        service.panel.panelController.setWorkspaceSearchQuery(query)
        Task { @MainActor in
            await service.panel.performWorkspaceSearch()
        }
    }

    func openMatch(_ match: EditorSearchMatch) {
        adapter?.service?.panel.openWorkspaceSearchMatch(
            EditorWorkspaceSearchMatch(
                url: match.uri,
                line: match.line,
                column: match.column,
                path: match.path,
                preview: match.preview
            )
        )
    }

    func openResultsInEditor() {
        adapter?.service?.panel.openWorkspaceSearchResultsInEditor()
    }

    private static func mapMatch(_ match: EditorWorkspaceSearchMatch) -> EditorSearchMatch {
        EditorSearchMatch(
            uri: match.url,
            line: match.line,
            column: match.column,
            path: match.path,
            preview: match.preview
        )
    }
}
