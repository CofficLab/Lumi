import Foundation
import Testing
@testable import EditorContracts

@Test func documentSelectorCombinesFiltersAndSupportsGlobMatching() {
    let document = EditorDocumentSummary(
        id: .makeUnique(),
        uri: URL(fileURLWithPath: "/workspace/Sources/Editor.swift"),
        languageID: "swift",
        revision: 1,
        isDirty: false,
        isReadOnly: false,
        largeFileMode: .normal
    )
    let selector = EditorDocumentSelector(
        languageID: "swift",
        scheme: "file",
        filenameGlob: "E*or.swift",
        fileExtension: "SWIFT",
        requiresLocalFile: true
    )

    #expect(selector.matches(document))
    #expect(EditorDocumentSelector.any.matches(document))
    #expect(!EditorDocumentSelector(languageID: "rust").matches(document))
    #expect(!EditorDocumentSelector(filenameGlob: "*.rs").matches(document))
    #expect(!EditorDocumentSelector(scheme: "untitled").matches(document))
    #expect(!EditorDocumentSelector(requiresLocalFile: true).matches(makeRemoteSummary()))
}

@Test func selectorGlobSupportsEmptyAndMultipleWildcardMatches() {
    #expect(EditorDocumentSelector.globPattern("*", matches: ""))
    #expect(EditorDocumentSelector.globPattern("Package@Swift-*", matches: "Package@Swift-6.0"))
    #expect(EditorDocumentSelector.globPattern("a**c", matches: "abbbc"))
    #expect(!EditorDocumentSelector.globPattern("a*c", matches: "abbd"))
}

@Test func pluginAPIVersionsRequireMatchingMajorAndNonNewerMinor() {
    let host = EditorPluginAPIVersion(major: 2, minor: 3)
    #expect(EditorPluginAPIVersion(major: 2, minor: 2).isCompatible(with: host))
    #expect(host.isCompatible(with: host))
    #expect(!EditorPluginAPIVersion(major: 2, minor: 4).isCompatible(with: host))
    #expect(!EditorPluginAPIVersion(major: 1, minor: 99).isCompatible(with: host))
    #expect(EditorPluginAPIVersion(major: 1, minor: 9) < EditorPluginAPIVersion(major: 2, minor: 0))
}

@Test func workbenchResolvesActiveGroupTabAndFlattenedTabs() {
    let first = makeTab(title: "first")
    let second = makeTab(title: "second")
    let firstGroup = EditorGroupState(id: .makeUnique(), tabs: [first], activeSessionID: first.id)
    let secondGroup = EditorGroupState(id: .makeUnique(), tabs: [second], activeSessionID: second.id)
    let workbench = EditorWorkbenchState(groups: [firstGroup, secondGroup], activeGroupID: secondGroup.id)

    #expect(workbench.activeGroup == secondGroup)
    #expect(workbench.activeTab == second)
    #expect(workbench.allTabs == [first, second])
    #expect(EditorWorkbenchState(groups: [firstGroup], activeGroupID: nil).activeGroup == firstGroup)
    #expect(EditorWorkbenchState(groups: [], activeGroupID: nil).activeTab == nil)
}

@Test func diagnosticsSnapshotCountsOnlyErrorsAndWarnings() {
    let uri = URL(fileURLWithPath: "/workspace/file.swift")
    func diagnostic(_ severity: EditorDiagnosticSeverity, _ id: String) -> EditorDiagnosticItem {
        EditorDiagnosticItem(
            id: id,
            documentURI: uri,
            range: EditorRange(at: .zero),
            severity: severity,
            message: id
        )
    }
    let snapshot = EditorDiagnosticsSnapshot(diagnostics: [
        diagnostic(.error, "e1"),
        diagnostic(.warning, "w1"),
        diagnostic(.information, "i1"),
        diagnostic(.hint, "h1"),
    ])

    #expect(snapshot.errorCount == 1)
    #expect(snapshot.warningCount == 1)
    #expect(EditorDiagnosticsSnapshot.empty.errorCount == 0)
}

private func makeRemoteSummary() -> EditorDocumentSummary {
    EditorDocumentSummary(
        id: .makeUnique(),
        uri: URL(string: "untitled://scratch/Editor.swift")!,
        languageID: "swift",
        revision: 0,
        isDirty: true,
        isReadOnly: false,
        largeFileMode: .normal
    )
}

private func makeTab(title: String) -> EditorSessionTab {
    EditorSessionTab(id: .makeUnique(), documentID: .makeUnique(), title: title)
}
