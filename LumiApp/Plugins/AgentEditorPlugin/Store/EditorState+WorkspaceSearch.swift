import Foundation

@MainActor
extension EditorState {
    func openWorkspaceSearchPanel() {
        let seededQuery = selectedTextForWorkspaceSearch()
            ?? activeSession.findReplaceState.findText.nilIfBlank
            ?? panelState.workspaceSearchQuery.nilIfBlank

        let shouldAutoSearch = panelState.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let seededQuery, shouldAutoSearch {
            panelController.setWorkspaceSearchQuery(seededQuery)
        }
        presentBottomPanel(.searchResults)
        if shouldAutoSearch, seededQuery != nil {
            Task { @MainActor in
                await performWorkspaceSearch()
            }
        }
    }

    func performWorkspaceSearch() async {
        let query = panelState.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            panelController.setWorkspaceSearchResults([], summary: nil, errorMessage: nil)
            return
        }
        guard let projectRootPath else {
            panelController.setWorkspaceSearchResults([], summary: nil, errorMessage: "Project root unavailable")
            presentBottomPanel(.searchResults)
            return
        }

        presentBottomPanel(.searchResults)
        panelController.setWorkspaceSearchLoading(true)
        panelController.setWorkspaceSearchResults([], summary: nil, errorMessage: nil)

        do {
            let response = try await EditorWorkspaceSearchController().search(
                query: query,
                projectRootPath: projectRootPath
            )
            panelController.setWorkspaceSearchLoading(false)
            panelController.setWorkspaceSearchResults(
                response.fileResults,
                summary: response.summary,
                errorMessage: nil
            )
        } catch {
            panelController.setWorkspaceSearchLoading(false)
            panelController.setWorkspaceSearchResults(
                [],
                summary: nil,
                errorMessage: error.localizedDescription
            )
            showStatusToast("Workspace search failed", level: .warning, duration: 1.8)
        }
    }

    func openWorkspaceSearchMatch(_ match: EditorWorkspaceSearchMatch) {
        performNavigation(.definition(match.url, .init(line: match.line, column: match.column), highlightLine: true))
    }

    func openWorkspaceSearchResultsInEditor() {
        guard let summary = panelState.workspaceSearchSummary,
              !panelState.workspaceSearchResults.isEmpty else {
            showStatusToast("No search results to open", level: .info, duration: 1.6)
            return
        }

        do {
            let url = try EditorWorkspaceSearchController().exportSearchEditor(
                summary: summary,
                fileResults: panelState.workspaceSearchResults
            )
            loadFile(from: url)
        } catch {
            showStatusToast("Failed to open search editor", level: .warning, duration: 1.8)
        }
    }

    private func selectedTextForWorkspaceSearch() -> String? {
        guard let focusedTextView,
              let selection = focusedTextView.selectionManager.textSelections.first else {
            return nil
        }
        let range = selection.range
        guard range.location != NSNotFound,
              range.length > 0,
              let swiftRange = Range(range, in: focusedTextView.string) else {
            return nil
        }
        return String(focusedTextView.string[swiftRange])
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
