#if canImport(XCTest)
import Foundation
import KernelLumi
import LanguageServerProtocol
import XCTest
@testable import EditorService
// 消歧：与 EditorLanguageRuntime 的同名类型区分，贡献包使用 KernelLumi 一侧。
import struct KernelLumi.EditorLanguageDescriptor

/// V2 契约适配器新增能力（诊断/符号/面板/引用/调用层级/工作区搜索）的映射逻辑测试。
@MainActor
final class EditorProvidingV2AdapterCapabilityTests: XCTestCase {
    private var service: EditorService!
    private var adapter: EditorProvidingV2Adapter!

    override func setUp() {
        super.setUp()
        service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        adapter = EditorProvidingV2Adapter(service: service)
    }

    override func tearDown() {
        adapter = nil
        service = nil
        super.tearDown()
    }

    private func makeRange(_ startLine: Int, _ startChar: Int, _ endLine: Int, _ endChar: Int) -> LSPRange {
        LSPRange(
            start: Position(line: startLine, character: startChar),
            end: Position(line: endLine, character: endChar)
        )
    }

    private func flushAsync() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    // MARK: - Documents

    func testOpenDocumentLoadsContentAndActivatesSession() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2AdapterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Doc-A.swift")
        try Data("let x = 1\n".utf8).write(to: url)

        let sessionID = try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .activate))

        XCTAssertEqual(service.files.currentFileURL?.standardizedFileURL, url.standardizedFileURL)
        XCTAssertEqual(service.sessions.activeSessionID, sessionID.rawValue)
        XCTAssertNotNil(
            service.sessionStore.sessions.first { $0.id == sessionID.rawValue },
            "open 后应能在 sessionStore 中按返回的 session id 找到对应 session"
        )
    }

    func testOpenDocumentInBackgroundDoesNotActivate() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2AdapterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Doc-BG.swift")
        try Data("let y = 2\n".utf8).write(to: url)

        let activeBefore = service.sessions.activeSessionID
        _ = try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .background))

        XCTAssertEqual(service.sessions.activeSessionID, activeBefore)
        XCTAssertEqual(service.sessions.tabs.count, 1)
    }

    // MARK: - Diagnostics

    func testDiagnosticsSnapshotMapsSeverityMessageAndDocumentURI() {
        let uri = URL(fileURLWithPath: "/tmp/project/Diag.swift")
        service.state.testing_setCurrentFileURL(uri)
        service.panel.panelState.problemDiagnostics = [
            Diagnostic(range: makeRange(1, 0, 1, 5), severity: .error, source: "swift", message: "boom"),
            Diagnostic(range: makeRange(2, 0, 2, 3), severity: .warning, source: nil, message: "careful"),
            Diagnostic(range: makeRange(3, 0, 3, 1), severity: nil, source: nil, message: "info-ish"),
        ]

        let snapshot = adapter.diagnostics.snapshot
        XCTAssertEqual(snapshot.diagnostics.count, 3)
        XCTAssertEqual(snapshot.diagnostics[0].severity, .error)
        XCTAssertEqual(snapshot.diagnostics[0].message, "boom")
        XCTAssertEqual(snapshot.diagnostics[0].source, "swift")
        XCTAssertEqual(snapshot.diagnostics[1].severity, .warning)
        XCTAssertEqual(snapshot.diagnostics[2].severity, .hint, "nil severity 应回退为 hint")
        XCTAssertEqual(
            snapshot.diagnostics.map(\.documentURI).map { $0.standardizedFileURL },
            Array(repeating: uri.standardizedFileURL, count: 3),
            "诊断 documentURI 应取活动文档 URL"
        )
        XCTAssertEqual(snapshot.diagnostics[0].range.start.line, 1)
        XCTAssertEqual(snapshot.diagnostics[0].range.end.character, 5)
    }

    func testDiagnosticsSnapshotEmptyWhenNoServiceData() {
        XCTAssertTrue(adapter.diagnostics.snapshot.diagnostics.isEmpty)
    }

    // MARK: - Document Symbols

    private final class FakeSymbolProvider: SuperEditorDocumentSymbolProvider {
        var symbols: [EditorDocumentSymbolItem] = []
        var isLoading = false
        private(set) var refreshCount = 0
        func refresh() { refreshCount += 1 }
        func clear() { symbols = [] }
        func reset() {}
        func applySymbols(_ symbols: [EditorDocumentSymbolItem]) { self.symbols = symbols }
        func activeItems(for line: Int) -> [EditorDocumentSymbolItem] { [] }
        func activePathIDs(for line: Int) -> [String] { [] }
        func activeAncestorIDs(for line: Int) -> Set<String> { [] }
    }

    func testDocumentSymbolsMapTreeAndRefreshForwardsToProvider() async throws {
        let provider = FakeSymbolProvider()
        let child = EditorDocumentSymbolItem(
            id: "Foo/bar",
            name: "bar",
            detail: "() -> Void",
            kind: .method,
            range: makeRange(2, 4, 4, 5),
            selectionRange: makeRange(2, 4, 2, 7),
            children: []
        )
        let root = EditorDocumentSymbolItem(
            id: "Foo",
            name: "Foo",
            detail: nil,
            kind: .class,
            range: makeRange(0, 0, 10, 1),
            selectionRange: makeRange(0, 6, 0, 9),
            children: [child]
        )
        provider.applySymbols([root])
        service.editorExtensionRegistry.registerDocumentSymbolProvider(provider)

        // 能力为 lazy 装配：首次访问即从 provider 采样。
        let capability = adapter.documentSymbols
        let symbols = capability.activeSymbols
        XCTAssertEqual(capability.isLoading, false)
        XCTAssertEqual(symbols.count, 1)
        XCTAssertEqual(symbols[0].name, "Foo")
        XCTAssertEqual(symbols[0].kind, .class)
        XCTAssertEqual(symbols[0].children.count, 1)
        XCTAssertEqual(symbols[0].children.first?.name, "bar")
        XCTAssertEqual(symbols[0].children.first?.detail, "() -> Void")

        capability.refresh()
        XCTAssertEqual(provider.refreshCount, 1, "契约 refresh 应转发到宿主 provider")
    }

    // MARK: - Panel

    func testPanelPresentAndObserveRoundTrip() async throws {
        XCTAssertNil(adapter.panels.bottomPanel)

        adapter.panels.presentBottomPanel(.problems)
        await flushAsync()
        XCTAssertEqual(adapter.panels.bottomPanel, .problems)

        adapter.panels.presentBottomPanel(.callHierarchy)
        await flushAsync()
        XCTAssertEqual(adapter.panels.bottomPanel, .callHierarchy)

        adapter.panels.presentBottomPanel(nil)
        await flushAsync()
        XCTAssertNil(adapter.panels.bottomPanel)
    }

    // MARK: - References

    func testReferencesStateMapsResultsAndSelection() {
        let item = EditorReferenceResult(
            url: URL(fileURLWithPath: "/tmp/project/Ref.swift"),
            line: 4,
            column: 8,
            path: "Sources/Ref.swift",
            preview: "foo()"
        )
        service.panel.panelState.referenceResults = [item]
        service.panel.panelState.selectedReferenceResult = item

        let state = adapter.references.references
        XCTAssertEqual(state.results.count, 1)
        XCTAssertEqual(state.results[0].line, 4)
        XCTAssertEqual(state.results[0].column, 8)
        XCTAssertEqual(state.results[0].path, "Sources/Ref.swift")
        XCTAssertEqual(state.results[0].preview, "foo()")
        XCTAssertEqual(state.selected?.preview, "foo()")
    }

    // MARK: - Call Hierarchy

    private final class FakeCallHierarchyProvider: SuperEditorCallHierarchyProvider {
        var rootItem: EditorCallHierarchyItem?
        var incomingCalls: [EditorCallHierarchyCall] = []
        var outgoingCalls: [EditorCallHierarchyCall] = []
        var isLoading = false
        var isAvailable = true
        private(set) var lastPrepared: (uri: String, line: Int, character: Int)?
        private(set) var incomingRequested: [EditorCallHierarchyItem] = []
        private(set) var outgoingRequested: [EditorCallHierarchyItem] = []

        func prepareCallHierarchy(uri: String, line: Int, character: Int) async {
            lastPrepared = (uri, line, character)
        }

        func fetchIncomingCalls(item: EditorCallHierarchyItem) async {
            incomingRequested.append(item)
        }

        func fetchOutgoingCalls(item: EditorCallHierarchyItem) async {
            outgoingRequested.append(item)
        }

        func clear() {
            rootItem = nil
            incomingCalls = []
            outgoingCalls = []
        }

        func reset() {}
    }

    func testCallHierarchyPrepareAndRootMapping() async throws {
        let provider = FakeCallHierarchyProvider()
        service.editorExtensionRegistry.registerCallHierarchyProvider(provider)

        let uri = URL(fileURLWithPath: "/tmp/project/Hier.swift")
        adapter.callHierarchy.prepare(uri: uri, position: EditorPosition(line: 3, character: 6))
        await flushAsync()
        XCTAssertEqual(provider.lastPrepared?.line, 3)
        XCTAssertEqual(provider.lastPrepared?.character, 6)

        let root = EditorCallHierarchyItem(
            name: "run",
            kind: .function,
            uri: uri.absoluteString,
            range: makeRange(0, 0, 2, 1),
            selectionRange: makeRange(0, 6, 0, 9),
            data: nil
        )
        provider.rootItem = root
        let caller = EditorCallHierarchyItem(
            name: "main",
            kind: .function,
            uri: uri.absoluteString,
            range: makeRange(5, 0, 6, 1),
            selectionRange: makeRange(5, 6, 5, 10),
            data: nil
        )
        provider.incomingCalls = [EditorCallHierarchyCall(item: caller, fromRanges: [makeRange(6, 2, 6, 6)])]

        service.objectWillChange.send()
        await flushAsync()

        let hierarchy = adapter.callHierarchy.hierarchy
        let rootNode = try XCTUnwrap(hierarchy.root)
        XCTAssertEqual(rootNode.name, "run")
        XCTAssertEqual(rootNode.uri.standardizedFileURL, uri.standardizedFileURL)
        XCTAssertEqual(rootNode.selectionRange.start.character, 6)
        XCTAssertEqual(hierarchy.incoming.count, 1)
        XCTAssertEqual(hierarchy.incoming[0].node.name, "main")
        XCTAssertEqual(hierarchy.incoming[0].callRanges.first?.start.line, 6)
    }

    func testCallHierarchyFetchForRootNodeUsesRootItemFallback() async throws {
        let provider = FakeCallHierarchyProvider()
        service.editorExtensionRegistry.registerCallHierarchyProvider(provider)

        let root = EditorCallHierarchyItem(
            name: "root",
            kind: .method,
            uri: "file:///tmp/project/Hier.swift",
            range: makeRange(0, 0, 1, 1),
            selectionRange: makeRange(0, 0, 0, 4),
            data: .string("opaque-lsp-data")
        )
        provider.rootItem = root
        // 先触发 lazy 装配并订阅 objectWillChange，再发布变更。
        XCTAssertNil(adapter.callHierarchy.hierarchy.root)
        service.objectWillChange.send()
        await flushAsync()

        let rootNode = try XCTUnwrap(adapter.callHierarchy.hierarchy.root)

        // 根节点未经 edge 缓存，应通过 rootItem 回退解析（含 LSP data）。
        adapter.callHierarchy.fetchIncomingCalls(node: rootNode)
        adapter.callHierarchy.fetchOutgoingCalls(node: rootNode)
        await flushAsync()

        XCTAssertEqual(provider.incomingRequested.map(\.name), ["root"])
        XCTAssertEqual(provider.outgoingRequested.map(\.name), ["root"])
        XCTAssertEqual(provider.incomingRequested.first?.data, .string("opaque-lsp-data"))

        adapter.callHierarchy.clear()
        await flushAsync()
        XCTAssertNil(provider.rootItem)
    }

    // MARK: - Workspace Search

    func testWorkspaceSearchStateMapsResultsSummaryAndError() {
        let url = URL(fileURLWithPath: "/tmp/project/Search.swift")
        service.panel.panelState.workspaceSearchResults = [
            EditorWorkspaceSearchFileResult(
                url: url,
                path: "Sources/Search.swift",
                matches: [
                    EditorWorkspaceSearchMatch(
                        url: url, line: 3, column: 7, path: "Sources/Search.swift", preview: "let hit = 1"
                    )
                ]
            )
        ]
        service.panel.panelState.workspaceSearchSummary = EditorWorkspaceSearchSummary(
            query: "hit",
            totalMatches: 1,
            totalFiles: 1
        )
        service.panel.panelState.workspaceSearchErrorMessage = nil
        service.panel.panelState.isWorkspaceSearchLoading = false

        let state = adapter.workspaceSearch.search
        XCTAssertEqual(state.results.count, 1)
        XCTAssertEqual(state.results[0].path, "Sources/Search.swift")
        XCTAssertEqual(state.results[0].matches.first?.line, 3)
        XCTAssertEqual(state.results[0].matches.first?.preview, "let hit = 1")
        XCTAssertEqual(state.summary?.query, "hit")
        XCTAssertEqual(state.summary?.totalMatches, 1)
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.isLoading)
    }

    // MARK: - Extensions

    func testDefaultExtensionsHostingIsSharedWithServiceRegistry() async throws {
        LanguageRegistry.shared.reset()
        let bundle = makeValidBundle(pluginID: "com.test.minimal")
        try await adapter.extensions.replaceBundle(
            for: "com.test.minimal",
            with: bundle.stamped(pluginID: "com.test.minimal", generation: 1)
        )
        XCTAssertEqual(
            service.editorExtensionRegistry.installedPlugins.map(\.id),
            ["com.test.minimal"],
            "默认 EditorContributionRegistry 应包装 service 的 registry，installedPlugins 应同步"
        )
    }

    private func makeValidBundle(pluginID: String) -> EditorContributionBundle {
        EditorContributionBundle(
            pluginID: pluginID,
            languages: [
                EditorLanguageContribution(
                    language: EditorLanguageDescriptor(
                        languageId: "adapter.lang",
                        displayName: "Adapter Lang",
                        fileExtensions: ["adapterlang"]
                    )
                )
            ]
        )
    }
}
#endif
