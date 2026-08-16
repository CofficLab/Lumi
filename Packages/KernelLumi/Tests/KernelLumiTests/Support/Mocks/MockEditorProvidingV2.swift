import Combine
import Foundation
import SwiftUI
@testable import KernelLumi

/// 测试用 `EditorProvidingV2`：除 `extensions` 外的子能力均为最小 stub，
/// 用于验证 PluginManager 的贡献包装配（安装/撤回/盖戳）。
@MainActor
final class MockEditorProvidingV2: EditorProvidingV2 {
    let scope: EditorScope
    let documents: any EditorDocumentProviding
    let sessions: any EditorSessionProviding
    let selections: any EditorSelectionProviding
    let navigation: any EditorNavigationProviding
    let commands: any EditorCommandProviding
    let configuration: any EditorConfigurationProviding
    let diagnostics: any EditorDiagnosticsProviding
    let documentSymbols: any EditorDocumentSymbolProviding
    let panels: any EditorPanelProviding
    let references: any EditorReferencesProviding
    let callHierarchy: any EditorCallHierarchyProviding
    let workspaceSearch: any EditorWorkspaceSearchProviding
    let diff: any EditorDiffProviding
    let surface: any EditorSurfaceProviding
    let extensions: any EditorExtensionHosting

    init(extensions: MockEditorExtensionHosting = MockEditorExtensionHosting()) {
        self.scope = EditorScope(windowID: EditorWindowID(rawValue: UUID()), workspaceID: EditorWorkspaceID(rawValue: UUID()))
        self.documents = StubDocumentProviding()
        self.sessions = StubSessionProviding()
        self.selections = StubSelectionProviding()
        self.navigation = StubNavigationProviding()
        self.commands = StubCommandProviding()
        self.configuration = StubConfigurationProviding()
        self.diagnostics = StubDiagnosticsProviding()
        self.documentSymbols = StubDocumentSymbolProviding()
        self.panels = StubPanelProviding()
        self.references = StubReferencesProviding()
        self.callHierarchy = StubCallHierarchyProviding()
        self.workspaceSearch = StubWorkspaceSearchProviding()
        self.diff = StubDiffProviding()
        self.surface = StubSurfaceProviding()
        self.extensions = extensions
    }
}

/// 记录 `replaceBundle` 调用序列的扩展宿主。
@MainActor
final class MockEditorExtensionHosting: EditorExtensionHosting {
    private(set) var installedPluginIDs: [String] = []
    private(set) var withdrawnPluginIDs: [String] = []
    private(set) var stampedGenerations: [String: UInt64] = [:]
    private(set) var receivedLanguageIDs: [String] = []

    func replaceBundle(for pluginID: String, with bundle: EditorContributionBundle?) async throws {
        guard let bundle else {
            withdrawnPluginIDs.append(pluginID)
            return
        }
        installedPluginIDs.append(pluginID)
        stampedGenerations[pluginID] = bundle.generation
        receivedLanguageIDs.append(contentsOf: bundle.languages.map(\.language.languageId))
    }

    func availability(for feature: EditorFeature, document: EditorDocumentSummary) -> EditorFeatureAvailability {
        EditorFeatureAvailability(.noProvider)
    }
}

// MARK: - 子能力最小 stub

@MainActor
private final class StubDocumentProviding: EditorDocumentProviding {
    var activeDocument: EditorDocumentSummary? { nil }
    var statePublisher: AnyPublisher<EditorDocumentState, Never> {
        Just(EditorDocumentState(activeDocument: nil, documents: [])).eraseToAnyPublisher()
    }

    func snapshot(documentID: EditorDocumentID) async throws -> EditorDocumentSnapshot {
        throw EditorContractError.documentNotFound(documentID)
    }

    func open(_ request: EditorOpenRequest) async throws -> EditorSessionID {
        throw EditorContractError.capabilityUnavailable(feature: "stub")
    }

    func save(documentID: EditorDocumentID, reason: EditorSaveReason) async throws {}
    func saveAll(reason: EditorSaveReason) async throws {}
    func revert(documentID: EditorDocumentID) async throws {}
    func reload(documentID: EditorDocumentID) async throws {}
    func loadFullDocument(documentID: EditorDocumentID) async throws {}
    func apply(
        _ edit: EditorWorkspaceEdit,
        expectedRevisions: [EditorDocumentID: UInt64],
        options: EditorEditOptions
    ) async throws -> EditorWorkspaceEditResult {
        throw EditorContractError.capabilityUnavailable(feature: "stub")
    }
}

@MainActor
private final class StubSessionProviding: EditorSessionProviding {
    var state: EditorWorkbenchState { EditorWorkbenchState(groups: [], activeGroupID: nil) }
    var statePublisher: AnyPublisher<EditorWorkbenchState, Never> {
        Just(state).eraseToAnyPublisher()
    }

    func activate(sessionID: EditorSessionID) {}
    func close(sessionID: EditorSessionID, policy: EditorClosePolicy) async throws {}
    func closeOthers(keeping sessionID: EditorSessionID) async throws {}
    func closeToLeft(of sessionID: EditorSessionID) async throws {}
    func closeToRight(of sessionID: EditorSessionID) async throws {}
    func setPinned(_ pinned: Bool, sessionID: EditorSessionID) {}
    func move(sessionID: EditorSessionID, before: EditorSessionID?, in groupID: EditorGroupID) {}
    func split(sessionID: EditorSessionID, direction: EditorSplitDirection) -> EditorGroupID {
        EditorGroupID(rawValue: UUID())
    }

    func move(sessionID: EditorSessionID, to groupID: EditorGroupID) {}
    func navigateBack() {}
    func navigateForward() {}
}

@MainActor
private final class StubSelectionProviding: EditorSelectionProviding {
    var snapshot: EditorSelectionSnapshot {
        EditorSelectionSnapshot(selections: [], documentID: EditorDocumentID(rawValue: UUID()), revision: 0)
    }

    var statePublisher: AnyPublisher<EditorSelectionSnapshot, Never> {
        Just(snapshot).eraseToAnyPublisher()
    }

    func setSelections(_ selections: [EditorSelection], reveal: EditorRevealPolicy) {}
    func selectedText() async -> String? { nil }
    func addCursor(at position: EditorPosition) {}
    func addNextOccurrence() {}
    func addAllOccurrences() {}
    func clearSecondaryCursors() {}
}

@MainActor
private final class StubNavigationProviding: EditorNavigationProviding {
    func open(_ location: EditorLocation, options: EditorOpenOptions) {}
    func reveal(_ range: EditorRange, in documentID: EditorDocumentID) {}
    func peek(_ locations: [EditorLocation], origin: EditorLocation?) {}
    func goBack() {}
    func goForward() {}
}

@MainActor
private final class StubCommandProviding: EditorCommandProviding {
    func execute(_ id: EditorCommandID, arguments: [EditorCommandArgument]) async throws {}
    func presentation(matching query: String, context: EditorCommandContext) -> EditorCommandPresentation {
        EditorCommandPresentation(id: EditorCommandID(rawValue: "stub"), title: "Stub")
    }

    func keybinding(for commandID: EditorCommandID, context: EditorCommandContext) -> EditorKeybinding? { nil }
}

@MainActor
private final class StubConfigurationProviding: EditorConfigurationProviding {
    var snapshot: EditorConfigurationSnapshot {
        EditorConfigurationSnapshot(userValues: [:], workspaceValues: [:], languageOverrides: [:])
    }

    var statePublisher: AnyPublisher<EditorConfigurationSnapshot, Never> {
        Just(snapshot).eraseToAnyPublisher()
    }

    func resolvedValue(for key: EditorSettingKey, context: EditorConfigurationContext) -> EditorSettingValue? { nil }
    func update(_ value: EditorSettingValue?, for key: EditorSettingKey, scope: EditorSettingScope) throws {}
}

@MainActor
private final class StubDiagnosticsProviding: EditorDiagnosticsProviding {
    var snapshot: EditorDiagnosticsSnapshot { .empty }
    var statePublisher: AnyPublisher<EditorDiagnosticsSnapshot, Never> {
        Just(snapshot).eraseToAnyPublisher()
    }
}

@MainActor
private final class StubDocumentSymbolProviding: EditorDocumentSymbolProviding {
    var activeSymbols: [EditorDocumentSymbol] { [] }
    var isLoading: Bool { false }
    var statePublisher: AnyPublisher<EditorDocumentSymbolsState, Never> {
        Just(EditorDocumentSymbolsState(symbols: [], isLoading: false)).eraseToAnyPublisher()
    }

    func refresh() {}
}

@MainActor
private final class StubPanelProviding: EditorPanelProviding {
    var bottomPanel: EditorBottomPanel? { nil }
    var statePublisher: AnyPublisher<EditorBottomPanel?, Never> {
        Just(nil).eraseToAnyPublisher()
    }

    func presentBottomPanel(_ panel: EditorBottomPanel?) {}
}

@MainActor
private final class StubReferencesProviding: EditorReferencesProviding {
    var references: EditorReferencesState { .empty }
    var statePublisher: AnyPublisher<EditorReferencesState, Never> {
        Just(references).eraseToAnyPublisher()
    }
}

@MainActor
private final class StubCallHierarchyProviding: EditorCallHierarchyProviding {
    var hierarchy: EditorCallHierarchyState { .empty }
    var statePublisher: AnyPublisher<EditorCallHierarchyState, Never> {
        Just(hierarchy).eraseToAnyPublisher()
    }

    func prepare(uri: URL, position: EditorPosition) {}
    func fetchIncomingCalls(node: EditorCallHierarchyNode) {}
    func fetchOutgoingCalls(node: EditorCallHierarchyNode) {}
    func clear() {}
}

@MainActor
private final class StubWorkspaceSearchProviding: EditorWorkspaceSearchProviding {
    var search: EditorWorkspaceSearchState { .empty }
    var statePublisher: AnyPublisher<EditorWorkspaceSearchState, Never> {
        Just(search).eraseToAnyPublisher()
    }

    func performSearch(_ query: String) {}
    func openMatch(_ match: EditorSearchMatch) {}
    func openResultsInEditor() {}
}

@MainActor
private final class StubDiffProviding: EditorDiffProviding {
    var workingDiff: EditorV2DiffDocument? { nil }
    var statePublisher: AnyPublisher<EditorV2DiffDocument?, Never> {
        Just(nil).eraseToAnyPublisher()
    }

    func computeDiff(oldText: String, newText: String) -> [EditorV2DiffHunk] { [] }

    func accept(hunks: [EditorV2DiffHunk], in document: EditorDocumentID) async throws {}
}

@MainActor
private final class StubSurfaceProviding: EditorSurfaceProviding {
    func makeEditorView() -> AnyView {
        AnyView(EmptyView())
    }
}
