#if canImport(XCTest)
import EditorKernel
import LanguageServerProtocol
import XCTest
@testable import EditorService

final class LSPServerLifecyclePolicyTests: XCTestCase {
    private let projectPath = "/Users/me/Lumi"
    private let languageId = "swift"

    func testBuildServerPathChangeRequiresServerRestart() {
        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: nil,
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: nil,
                requestedBuildServerKind: nil
            ),
            "SourceKit must restart once buildServerPath becomes available"
        )
    }

    func testLegacyReuseLogicIgnoredBuildServerPathChange() {
        XCTAssertTrue(
            LSPServerLifecyclePolicy.legacyCanReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath
            ),
            "Old ensureServer guard reused the server even after buildServerPath became available"
        )

        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: nil,
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: nil,
                requestedBuildServerKind: nil
            )
        )
    }

    func testBuildServerKindExtractsInitializationOption() {
        XCTAssertEqual(
            LSPServerLifecyclePolicy.buildServerKind(from: ["buildServerKind": "manual"]),
            "manual"
        )
        XCTAssertNil(LSPServerLifecyclePolicy.buildServerKind(from: [:]))
    }

    func testBuildServerKindChangeRequiresServerRestart() {
        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: "/tmp/buildServer.json",
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: "xcode",
                requestedBuildServerKind: "manual"
            )
        )
    }

    func testBuildServerPathExtractsInitializationOption() {
        XCTAssertEqual(
            LSPServerLifecyclePolicy.buildServerPath(from: ["buildServerPath": "/tmp/buildServer.json"]),
            "/tmp/buildServer.json"
        )
        XCTAssertNil(LSPServerLifecyclePolicy.buildServerPath(from: [:]))
        XCTAssertNil(LSPServerLifecyclePolicy.buildServerPath(from: nil))
    }

    func testSameBuildServerPathCanReuseExistingServer() {
        XCTAssertTrue(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: "/tmp/buildServer.json",
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: "manual",
                requestedBuildServerKind: "manual"
            )
        )
    }

    func testBuildServerPathUpdateRequiresRestartEvenWhenPreviouslyAvailable() {
        XCTAssertFalse(
            LSPServerLifecyclePolicy.canReuseExistingServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: "/tmp/old.json",
                requestedBuildServerPath: "/tmp/new.json",
                activeBuildServerKind: "manual",
                requestedBuildServerKind: "manual"
            )
        )
    }

    func testStartTaskSignatureIncludesBuildServerPath() {
        XCTAssertNotEqual(
            LSPServerLifecyclePolicy.startTaskSignature(
                languageId: languageId,
                projectPath: projectPath,
                buildServerPath: nil,
                buildServerKind: nil
            ),
            LSPServerLifecyclePolicy.startTaskSignature(
                languageId: languageId,
                projectPath: projectPath,
                buildServerPath: "/tmp/buildServer.json",
                buildServerKind: nil
            ),
            "In-flight server start tasks must not be reused after buildServerPath becomes available"
        )
    }

    func testOpenDocumentRegressionWhenBuildServerPathBecomesAvailable() {
        XCTAssertTrue(
            LSPServerLifecyclePolicy.legacyOpenDocumentWouldSkipEnsureServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId
            ),
            "Pre-fix openDocument kept a stale SourceKit session after build context became ready"
        )

        XCTAssertTrue(
            LSPServerLifecyclePolicy.openDocumentShouldEnsureServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: nil,
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: nil,
                requestedBuildServerKind: nil
            ),
            "openDocument must re-run ensureServer so buildServerPath changes restart SourceKit"
        )
    }

    func testOpenDocumentDoesNotRestartWhenContextUnchanged() {
        XCTAssertFalse(
            LSPServerLifecyclePolicy.openDocumentShouldEnsureServer(
                hasServer: true,
                activeLanguageId: languageId,
                requestedLanguageId: languageId,
                activeProjectPath: projectPath,
                requestedProjectPath: projectPath,
                activeBuildServerPath: "/tmp/buildServer.json",
                requestedBuildServerPath: "/tmp/buildServer.json",
                activeBuildServerKind: "manual",
                requestedBuildServerKind: "manual"
            )
        )
    }
}

final class EditorProjectContextLSPRefreshPolicyTests: XCTestCase {
    func testRefreshWhenBuildContextBecomesAvailable() {
        XCTAssertTrue(
            EditorProjectContextLSPRefreshPolicy.shouldRefreshOpenDocument(
                isStructuredProject: true,
                contextStatus: .available("Lumi"),
                hasOpenFile: true
            )
        )
    }

    func testNoRefreshWhileBuildContextStillResolving() {
        XCTAssertFalse(
            EditorProjectContextLSPRefreshPolicy.shouldRefreshOpenDocument(
                isStructuredProject: true,
                contextStatus: .resolving,
                hasOpenFile: true
            )
        )
    }

    func testNoRefreshWithoutOpenFile() {
        XCTAssertFalse(
            EditorProjectContextLSPRefreshPolicy.shouldRefreshOpenDocument(
                isStructuredProject: true,
                contextStatus: .available("Lumi"),
                hasOpenFile: false
            )
        )
    }

    func testNoRefreshForNonStructuredProject() {
        XCTAssertFalse(
            EditorProjectContextLSPRefreshPolicy.shouldRefreshOpenDocument(
                isStructuredProject: false,
                contextStatus: .available(nil),
                hasOpenFile: true
            )
        )
    }

    func testDefaultEditorHostNotificationDoesNotMatchBridgeContract() {
        let bridgeNotification = Notification.Name("lumiEditorProjectContextDidChange")
        XCTAssertNotEqual(
            EditorHostEnvironment.Notifications().projectContextDidChange,
            bridgeNotification,
            "EditorState will miss Bridge updates unless Swift plugin reconfigures EditorHostEnvironment"
        )
    }
}

final class LSPDiagnosticBuildContextPolicyTests: XCTestCase {
    private func makeDiagnostic(message: String) -> Diagnostic {
        Diagnostic(
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 1)
            ),
            severity: .error,
            message: message
        )
    }

    func testSuppressesNoSuchModuleBeforeBuildContextReady() {
        let diagnostic = makeDiagnostic(message: "No such module 'LumiCoreKit'")

        XCTAssertFalse(
            LSPDiagnosticBuildContextPolicy.shouldPublishDiagnostic(
                diagnostic,
                buildServerPathAvailable: false
            )
        )
    }

    func testPublishesNoSuchModuleAfterBuildContextReady() {
        let diagnostic = makeDiagnostic(message: "No such module 'LumiCoreKit'")

        XCTAssertTrue(
            LSPDiagnosticBuildContextPolicy.shouldPublishDiagnostic(
                diagnostic,
                buildServerPathAvailable: true
            )
        )
    }

    func testSuppressesKnownModuleDiagnosticAfterBuildContextReady() {
        let diagnostic = makeDiagnostic(message: "No such module 'MagicKit'")

        XCTAssertFalse(
            LSPDiagnosticBuildContextPolicy.shouldPublishDiagnostic(
                diagnostic,
                buildServerPathAvailable: true,
                knownModuleNames: ["MagicKit"]
            )
        )
    }

    func testPublishesOtherDiagnosticsBeforeBuildContextReady() {
        let diagnostic = makeDiagnostic(message: "Cannot find type 'Foo' in scope")

        XCTAssertTrue(
            LSPDiagnosticBuildContextPolicy.shouldPublishDiagnostic(
                diagnostic,
                buildServerPathAvailable: false
            )
        )
    }
}

@MainActor
final class TrackingLSPClient: SuperEditorLSPClient {
    private(set) var refreshCallCount = 0

    func setProjectRootPath(_ path: String?) {}
    func openFile(uri: String, languageId: String, content: String, version: Int) async {}
    func refreshOpenDocumentForUpdatedProjectContext() async {
        refreshCallCount += 1
    }
    func closeFile() {}
    func updateDocumentSnapshot(_ content: String) {}
    func contentDidChange(range: LSPRange, text: String, version: Int) {}
    func replaceDocument(_ content: String, version: Int) {}
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] { [] }
    func requestCompletionDebounced(line: Int, character: Int) async -> [CompletionItem] { [] }
    func completionTriggerCharacters() -> Set<String> { [] }
    func requestHoverRaw(line: Int, character: Int) async -> Hover? { nil }
    func requestHoverRawDebounced(line: Int, character: Int) async -> Hover? { nil }
    func requestDefinition(line: Int, character: Int) async -> Location? { nil }
    func requestDeclaration(line: Int, character: Int) async -> Location? { nil }
    func requestTypeDefinition(line: Int, character: Int) async -> Location? { nil }
    func requestImplementation(line: Int, character: Int) async -> Location? { nil }
    func requestReferences(line: Int, character: Int) async -> [Location] { [] }
    func requestDocumentSymbols() async -> [DocumentSymbol] { [] }
    func requestWorkspaceSymbols(query: String) async -> WorkspaceSymbolResponse { nil }
    func requestDocumentHighlight(line: Int, character: Int) async -> [DocumentHighlight] { [] }
    func requestDocumentHighlightThrottled(line: Int, character: Int) async -> [DocumentHighlight] { [] }
    func requestSignatureHelp(line: Int, character: Int) async -> SignatureHelp? { nil }
    func requestSignatureHelpDebounced(line: Int, character: Int) async -> SignatureHelp? { nil }
    func requestInlayHint(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? { nil }
    func requestInlayHintThrottled(startLine: Int, startCharacter: Int, endLine: Int, endCharacter: Int) async -> [InlayHint]? { nil }
    func requestCodeAction(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction] { [] }
    func requestCodeActionDebounced(range: LSPRange, diagnostics: [Diagnostic], triggerKinds: [CodeActionKind]?) async -> [CodeAction] { [] }
    func resolveCodeAction(_ action: CodeAction) async -> CodeAction? { nil }
    func requestFoldingRange() async -> [FoldingRange] { [] }
    func requestFoldingRangeDebounced() async -> [FoldingRange] { [] }
    func requestFormatting(tabSize: Int, insertSpaces: Bool) async -> [TextEdit]? { nil }
    func requestRename(line: Int, character: Int, newName: String) async -> WorkspaceEdit? { nil }
    func requestCallHierarchy(line: Int, character: Int) async {}
    func requestSelectionRange(line: Int, character: Int) async -> [SelectionRange] { [] }
    func requestDocumentLinks() async -> [DocumentLink] { [] }
    func requestDocumentColors() async -> [ColorInformation] { [] }
    func documentDidSave(uri: String, text: String?) {}
    func executeCommand(command: String, arguments: [LSPAny]?) async -> LSPAny? { nil }
    var hasActiveWork: Bool { false }
    var supportsInlayHints: Bool { false }
    var supportsWillSave: Bool { false }
    var supportsWillSaveWaitUntil: Bool { false }
    var codeActionResolveSupported: Bool { false }
    var isAvailable: Bool { false }
}

@MainActor
private final class MockProjectContextCapability: SuperEditorProjectContextCapability {
    let id = "mock.project.context"
    var snapshot: EditorProjectContextSnapshot?

    func projectOpened(at path: String) async {}
    func projectClosed() {}
    func resyncProjectContext() async {}

    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot? {
        snapshot
    }

    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?) {}
}

@MainActor
final class EditorProjectContextLSPRefreshIntegrationTests: XCTestCase {
    private var previousEnvironment: EditorHostEnvironment!
    private var tempDirectory: URL!

    override func setUp() async throws {
        previousEnvironment = EditorHostEnvironment.current
        let notifications = EditorHostEnvironment.Notifications(
            projectContextDidChange: Notification.Name("lumiEditorProjectContextDidChange")
        )
        EditorHostEnvironment.configure(
            EditorHostEnvironment(notifications: notifications)
        )

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorProjectContextLSPRefreshTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        EditorHostEnvironment.configure(previousEnvironment)
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testEditorStateRefreshesLSPWhenBuildContextBecomesAvailable() async throws {
        let trackingClient = TrackingLSPClient()
        let capability = MockProjectContextCapability()
        let fileURL = try makeSwiftFile(named: "RootView.swift")
        capability.snapshot = makeSnapshot(
            projectPath: tempDirectory.path,
            filePath: fileURL.path,
            status: .available("Lumi")
        )

        let registry = EditorExtensionRegistry()
        registry.registerSuperEditorLSPClient(trackingClient)
        registry.registerProjectContextCapability(capability)

        let state = try await makeLoadedState(
            registry: registry,
            projectPath: tempDirectory.path,
            fileURL: fileURL
        )

        await state.handleProjectContextDidChangeForTesting()

        XCTAssertEqual(
            trackingClient.refreshCallCount,
            1,
            "EditorState must refresh SourceKit after build context becomes available"
        )
    }

    func testEditorStateDoesNotRefreshLSPWhileBuildContextStillResolving() async throws {
        let trackingClient = TrackingLSPClient()
        let capability = MockProjectContextCapability()
        let fileURL = try makeSwiftFile(named: "RootView.swift")
        capability.snapshot = makeSnapshot(
            projectPath: tempDirectory.path,
            filePath: fileURL.path,
            status: .resolving
        )

        let registry = EditorExtensionRegistry()
        registry.registerSuperEditorLSPClient(trackingClient)
        registry.registerProjectContextCapability(capability)

        let state = try await makeLoadedState(
            registry: registry,
            projectPath: tempDirectory.path,
            fileURL: fileURL
        )

        await state.handleProjectContextDidChangeForTesting()

        XCTAssertEqual(trackingClient.refreshCallCount, 0)
    }

    func testEditorStateReceivesBridgeNotificationAfterRefreshExtensionProviders() async throws {
        let trackingClient = TrackingLSPClient()
        let capability = MockProjectContextCapability()
        let fileURL = try makeSwiftFile(named: "RootView.swift")
        capability.snapshot = makeSnapshot(
            projectPath: tempDirectory.path,
            filePath: fileURL.path,
            status: .available("Lumi")
        )

        let registry = EditorExtensionRegistry()
        registry.registerSuperEditorLSPClient(trackingClient)
        registry.registerProjectContextCapability(capability)

        let state = try await makeLoadedState(
            registry: registry,
            projectPath: tempDirectory.path,
            fileURL: fileURL,
            refreshExtensions: false
        )

        EditorHostEnvironment.configure(
            EditorHostEnvironment(
                notifications: EditorHostEnvironment.Notifications(
                    projectContextDidChange: Notification.Name("lumiEditorProjectContextDidChange")
                )
            )
        )
        state.refreshExtensionProviders()

        let deadline = Date().addingTimeInterval(2)
        while trackingClient.refreshCallCount == 0, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(
            trackingClient.refreshCallCount,
            1,
            "refreshExtensionProviders must rebind notifications and catch up missed build context"
        )

        let refreshCountBeforeNotification = trackingClient.refreshCallCount
        NotificationCenter.default.post(
            name: Notification.Name("lumiEditorProjectContextDidChange"),
            object: nil
        )

        let notificationDeadline = Date().addingTimeInterval(2)
        while trackingClient.refreshCallCount == refreshCountBeforeNotification, Date() < notificationDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(
            trackingClient.refreshCallCount,
            refreshCountBeforeNotification + 1,
            "EditorState must observe Bridge notifications after extension registration"
        )
    }

    private func makeSwiftFile(named name: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try "import EditorService\n".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func makeLoadedState(
        registry: EditorExtensionRegistry,
        projectPath: String,
        fileURL: URL,
        refreshExtensions: Bool = false
    ) async throws -> EditorState {
        let state = EditorState(editorExtensions: registry)
        if refreshExtensions {
            state.refreshExtensionProviders()
        }
        state.projectRootPath = projectPath
        state.loadFile(from: fileURL)

        let deadline = Date().addingTimeInterval(2)
        while state.currentFileURL == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNotNil(state.currentFileURL, "Expected loadFile to populate currentFileURL for LSP refresh test")
        return state
    }

    private func makeSnapshot(
        projectPath: String,
        filePath: String,
        status: EditorProjectContextStatus
    ) -> EditorProjectContextSnapshot {
        EditorProjectContextSnapshot(
            projectPath: projectPath,
            workspaceName: "Lumi",
            workspacePath: projectPath + "/Lumi.xcodeproj",
            activeScheme: "Lumi",
            activeSchemeBuildableTargets: ["Lumi"],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            contextStatus: status,
            isStructuredProject: true,
            schemes: ["Lumi"],
            configurations: ["Debug", "Release"],
            currentFilePath: filePath,
            currentFilePrimaryTarget: "Lumi",
            currentFileMatchedTargets: ["Lumi"],
            currentFileIsInTarget: true,
            isTargetMembershipResolved: true
        )
    }
}

@MainActor
final class LSPServiceInitializationOptionsTests: XCTestCase {
    private final class MockLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability {
        let id = "mock.language.integration"
        var buildServerPath: String?

        func supports(languageId: String, projectPath: String?) -> Bool {
            languageId == "swift" && projectPath != nil
        }

        func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
            [EditorWorkspaceFolder(uri: "file://\(projectPath)", name: "Lumi")]
        }

        func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
            guard let buildServerPath else { return nil }
            return ["buildServerPath": buildServerPath, "scheme": "Lumi"]
        }
    }

    override func setUp() async throws {
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(MockLanguageIntegrationCapability())
        LSPService.shared.configureRegistry(registry)
    }

    override func tearDown() async throws {
        LSPService.shared.stopAll()
        LSPService.shared.configureRegistry(EditorExtensionRegistry())
    }

    func testInitializationOptionsMissingUntilBuildServerIsReady() {
        let capability = MockLanguageIntegrationCapability()
        capability.buildServerPath = nil
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(capability)
        LSPService.shared.configureRegistry(registry)

        XCTAssertNil(
            LSPService.makeInitializationOptions(for: "swift", projectPath: "/Users/me/Lumi")
        )
        XCTAssertNil(
            LSPService.currentBuildServerPath(for: "swift", projectPath: "/Users/me/Lumi")
        )
    }

    func testInitializationOptionsIncludeBuildServerPathWhenReady() {
        let capability = MockLanguageIntegrationCapability()
        capability.buildServerPath = "/tmp/buildServer.json"
        let registry = EditorExtensionRegistry()
        registry.registerLanguageIntegrationCapability(capability)
        LSPService.shared.configureRegistry(registry)

        XCTAssertNotNil(
            LSPService.makeInitializationOptions(for: "swift", projectPath: "/Users/me/Lumi")
        )
        XCTAssertEqual(
            LSPService.currentBuildServerPath(for: "swift", projectPath: "/Users/me/Lumi"),
            "/tmp/buildServer.json"
        )
    }
}
#endif
