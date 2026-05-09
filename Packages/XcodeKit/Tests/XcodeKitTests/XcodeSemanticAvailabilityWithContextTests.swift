import XCTest
@testable import XcodeKit

// MARK: - Mock Context Provider

@MainActor
final class MockXcodeContextProvider: XcodeContextProviding {
    
    var cachedState: BridgeCachedState?
    var buildContextProvider: XcodeBuildContextProvider?
    var cachedActiveScheme: String?
    var activeDestination: String?
    
    init(
        cachedState: BridgeCachedState? = nil,
        buildContextProvider: XcodeBuildContextProvider? = nil,
        cachedActiveScheme: String? = nil,
        activeDestination: String? = nil
    ) {
        self.cachedState = cachedState
        self.buildContextProvider = buildContextProvider
        self.cachedActiveScheme = cachedActiveScheme
        self.activeDestination = activeDestination
    }
}

// MARK: - XcodeSemanticAvailabilityWithContextTests

final class XcodeSemanticAvailabilityWithContextTests: XCTestCase {
    
    // MARK: - inspectWorkspaceContext(contextProvider:) Tests
    
    @MainActor
    func testInspectWorkspaceContextNonXcodeProject() {
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(cachedState: state)
        
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(contextProvider: provider)
        XCTAssertTrue(report.reasons.isEmpty)
    }
    
    @MainActor
    func testInspectWorkspaceContextNotInitialized() {
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: true,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(cachedState: state)
        
        let report = XcodeSemanticAvailability.inspectWorkspaceContext(contextProvider: provider)
        XCTAssertTrue(report.hasBlockingIssue)
        XCTAssertEqual(report.reasons.first?.id, "server-not-started")
    }
    
    // MARK: - inspectCurrentFileContext(contextProvider:) Tests
    
    @MainActor
    func testInspectCurrentFileContextNilURI() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        // nil URI should fall back to workspace inspection
        let report = XcodeSemanticAvailability.inspectCurrentFileContext(uri: nil, contextProvider: provider)
        XCTAssertTrue(report.reasons.isEmpty)
    }
    
    // MARK: - workspacePreflightError Tests
    
    @MainActor
    func testWorkspacePreflightErrorNoError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: "/path",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let error = XcodeSemanticAvailability.workspacePreflightError(
            operation: "Go to Definition",
            strength: .hard,
            contextProvider: provider
        )
        XCTAssertNil(error)
    }
    
    @MainActor
    func testWorkspacePreflightMessageNoError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: "/path",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let message = XcodeSemanticAvailability.workspacePreflightMessage(
            operation: "Go to Definition",
            strength: .hard,
            contextProvider: provider
        )
        XCTAssertNil(message)
    }
    
    // MARK: - preflightMessage Tests
    
    @MainActor
    func testPreflightMessageNoError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let message = XcodeSemanticAvailability.preflightMessage(
            uri: nil,
            operation: "Go to Definition",
            strength: .hard,
            contextProvider: provider
        )
        XCTAssertNil(message)
    }
    
    // MARK: - missingResultMessage Tests
    
    @MainActor
    func testMissingResultMessageNonXcodeProject() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        // Non-Xcode project should return nil (symbolNotFound is suppressed)
        let message = XcodeSemanticAvailability.missingResultMessage(
            uri: "file:///test.swift",
            operation: "Go to Definition",
            contextProvider: provider
        )
        XCTAssertNil(message)
    }
    
    // MARK: - classify Tests
    
    @MainActor
    func testClassifyDisconnectedError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let disconnectedError = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "dataStreamClosed"
        ])
        let result = XcodeSemanticAvailability.classify(
            disconnectedError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: "foo", operation: "test"),
            contextProvider: provider
        )
        
        XCTAssertEqual(result, .serverDisconnected)
    }
    
    @MainActor
    func testClassifyTimeoutError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let timeoutError = NSError(domain: "test", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Request timed out"
        ])
        let result = XcodeSemanticAvailability.classify(
            timeoutError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: "foo", operation: "test"),
            contextProvider: provider
        )
        
        XCTAssertEqual(result, .requestTimeout)
    }
    
    @MainActor
    func testClassifyProtocolTransportError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let transportError = NSError(domain: "test", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "ProtocolTransportError: connection closed"
        ])
        let result = XcodeSemanticAvailability.classify(
            transportError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: "foo", operation: "test"),
            contextProvider: provider
        )
        
        XCTAssertEqual(result, .serverDisconnected)
    }
    
    @MainActor
    func testClassifyNoProjectContextError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: nil,
            activeScheme: nil,
            activeConfiguration: nil,
            activeDestination: nil,
            buildContextStatus: "Unknown",
            isXcodeProject: false,
            isInitialized: false,
            workspaceName: nil,
            workspacePath: nil,
            schemes: [],
            configurations: [],
            projectPath: nil
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let genericError = NSError(domain: "test", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Something went wrong"
        ])
        let result = XcodeSemanticAvailability.classify(
            genericError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: "foo", operation: "test"),
            contextProvider: provider
        )
        
        XCTAssertEqual(result, .noProjectContext)
    }
    
    @MainActor
    func testClassifySymbolNotResolvedError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: "/path",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let nilError = NSError(domain: "test", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Result is nil"
        ])
        let result = XcodeSemanticAvailability.classify(
            nilError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: "myFunc", operation: "test"),
            contextProvider: provider
        )
        
        XCTAssertEqual(result, .symbolNotResolved(symbolName: "myFunc"))
    }
    
    @MainActor
    func testClassifyUnknownError() {
        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let resolver = XcodeProjectResolver()
        let buildProvider = XcodeBuildContextProvider(resolver: resolver, store: store)
        
        let state = BridgeCachedState(
            workspaceFolders: nil,
            buildServerPath: "/path",
            activeScheme: "App",
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            buildContextStatus: "Available",
            isXcodeProject: true,
            isInitialized: true,
            workspaceName: "WS",
            workspacePath: "/ws",
            schemes: ["App"],
            configurations: ["Debug"],
            projectPath: "/test"
        )
        let provider = MockXcodeContextProvider(
            cachedState: state,
            buildContextProvider: buildProvider
        )
        
        let weirdError = NSError(domain: "test", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Unexpected error occurred"
        ])
        let result = XcodeSemanticAvailability.classify(
            weirdError,
            context: LSPErrorContext(uri: "file:///test.swift", symbolName: nil, operation: "test"),
            contextProvider: provider
        )
        
        if case .unknown(let message) = result {
            XCTAssertTrue(message.contains("Unexpected error occurred"))
        } else {
            XCTFail("Expected unknown error")
        }
    }
}
