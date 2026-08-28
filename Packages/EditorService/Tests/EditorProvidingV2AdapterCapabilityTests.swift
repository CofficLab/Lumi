#if canImport(XCTest)
import EditorContracts
import Foundation
import LanguageServerProtocol
import XCTest
@testable import EditorService
// 消歧：与 EditorLanguageRuntime 的同名类型区分，贡献包使用中立契约层模型。
import struct EditorContracts.EditorLanguageDescriptor

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

// MARK: - Diff（Phase 7 §15.5）

extension EditorProvidingV2AdapterCapabilityTests {
    func testComputeDiffProducesHunksWithLineKinds() {
        let hunks = adapter.diff.computeDiff(
            oldText: "a\nb\nc\n",
            newText: "a\nB\nc\n"
        )
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks[0].removedContents, ["b"])
        XCTAssertEqual(hunks[0].addedContents, ["B"])
        XCTAssertEqual(hunks[0].oldChangeRange, 2...2)
        XCTAssertEqual(hunks[0].newChangeRange, 2...2)
    }

    func testWorkingDiffEmptyWithoutDocument() {
        XCTAssertNil(adapter.diff.workingDiff)
    }

    func testWorkingDiffReflectsBufferVersusDisk() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2AdapterDiffTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Diff.swift")
        try Data("alpha\nbeta\ngamma\n".utf8).write(to: url)

        _ = try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .activate))
        await flushAsync()

        // 缓冲与磁盘一致 → 空 hunks。
        let clean = try XCTUnwrap(adapter.diff.workingDiff)
        XCTAssertEqual(clean.uri.standardizedFileURL, url.standardizedFileURL)
        XCTAssertTrue(clean.isEmpty)

        // 修改缓冲 → workingDiff 出现 hunk。
        _ = service.files.replaceCurrentDocumentText("alpha\nBETA\ngamma\n", reason: "test")
        await flushAsync()
        let dirty = try XCTUnwrap(adapter.diff.workingDiff)
        XCTAssertEqual(dirty.hunks.count, 1)
        XCTAssertEqual(dirty.hunks[0].removedContents, ["beta"])
        XCTAssertEqual(dirty.hunks[0].addedContents, ["BETA"])
    }

    func testAcceptHunksAppliesOnlyAcceptedHunks() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2AdapterDiffAcceptTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        // 两处远距变更 → 两个独立 hunk；只接受其一验证逐块接受语义。
        let oldText = (1...20).map { "line\($0)" }.joined(separator: "\n") + "\n"
        let newText = (1...20).map { $0 == 2 ? "CHANGED-2" : ($0 == 18 ? "CHANGED-18" : "line\($0)") }
            .joined(separator: "\n") + "\n"
        let url = dir.appendingPathComponent("Accept.swift")
        try Data(oldText.utf8).write(to: url)

        _ = try await adapter.documents.open(EditorOpenRequest(uri: url, kind: .activate))
        await flushAsync()
        let documentID = try XCTUnwrap(adapter.activeDocumentID())

        let hunks = adapter.diff.computeDiff(oldText: oldText, newText: newText)
        XCTAssertEqual(hunks.count, 2, "distant changes split into two hunks")

        // 只接受第二个 hunk（line-18 变更）。
        let acceptedHunk = try XCTUnwrap(hunks.last)
        try await adapter.diff.accept(hunks: [acceptedHunk], in: documentID)
        await flushAsync()

        let text = service.state.content?.string ?? ""
        XCTAssertTrue(text.contains("CHANGED-18"), "accepted hunk applied: \(text)")
        XCTAssertFalse(text.contains("CHANGED-2"), "rejected hunk not applied: \(text)")
        XCTAssertTrue(text.contains("line2\n"), "rejected region intact: \(text)")
    }
}
