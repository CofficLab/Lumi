import SwiftUI
import MagicKit

struct BottomEditorWorkspaceSearchPanelView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var state: EditorState
    var showsToolbar: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsToolbar {
                toolbar
                Divider()
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            TextField(
                "Search in files",
                text: Binding(
                    get: { state.panelState.workspaceSearchQuery },
                    set: { state.panelController.setWorkspaceSearchQuery($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                Task { @MainActor in
                    await state.performWorkspaceSearch()
                }
            }

            Button("Search") {
                Task { @MainActor in
                    await state.performWorkspaceSearch()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.panelState.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button("Open Search Editor") {
                state.openWorkspaceSearchResultsInEditor()
            }
            .buttonStyle(.bordered)
            .disabled(state.panelState.workspaceSearchResults.isEmpty)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if state.panelState.isWorkspaceSearchLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Searching workspace…")
                    .font(.system(size: 12))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.panelState.workspaceSearchErrorMessage {
            emptyState(error, systemImage: "exclamationmark.triangle")
        } else if state.panelState.workspaceSearchQuery.isEmpty {
            emptyState("Enter a query and press Return", systemImage: "magnifyingglass")
        } else if state.panelState.workspaceSearchResults.isEmpty {
            emptyState("No results", systemImage: "doc.text.magnifyingglass")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let summary = state.panelState.workspaceSearchSummary {
                        Text("\(summary.totalMatches) matches in \(summary.totalFiles) files")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    }

                    ForEach(state.panelState.workspaceSearchResults) { file in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                state.panelController.toggleWorkspaceSearchFileCollapse(path: file.path)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isCollapsed(file) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

                                    Text(file.path)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

                                    Spacer()

                                    Text(fileMatchSummary(file))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                                }
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed(file) {
                                ForEach(file.matches) { match in
                                    Button {
                                        state.openWorkspaceSearchMatch(match)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("L\(match.line):C\(match.column)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                                                .frame(width: 62, alignment: .leading)

                                            Text(match.preview)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(rowBackground(for: match))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(rowBorder(for: match), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.035))
                        )
                    }
                }
                .padding(10)
            }
        }
    }

    private func isCollapsed(_ file: EditorWorkspaceSearchFileResult) -> Bool {
        state.panelState.workspaceSearchCollapsedFilePaths.contains(file.path)
    }

    private func fileMatchSummary(_ file: EditorWorkspaceSearchFileResult) -> String {
        let noun = file.matchCount == 1 ? "match" : "matches"
        return "\(file.matchCount) \(noun)"
    }

    private func rowBackground(for match: EditorWorkspaceSearchMatch) -> Color {
        state.panelState.selectedWorkspaceSearchMatchID == match.id
            ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.1)
            : themeVM.activeAppTheme.workspaceTextColor().opacity(0.05)
    }

    private func rowBorder(for match: EditorWorkspaceSearchMatch) -> Color {
        state.panelState.selectedWorkspaceSearchMatchID == match.id
            ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.18)
            : .clear
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
