import EditorService
import LumiUI
import SwiftUI

public struct BottomEditorWorkspaceSearchPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    public var showsToolbar: Bool = true

    public init(service: EditorService, showsToolbar: Bool = true) {
        self._service = ObservedObject(wrappedValue: service)
        self.showsToolbar = showsToolbar
    }

    public var body: some View {
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
                String(localized: "Search in files", bundle: .module),
                text: Binding(
                    get: { service.panelState.workspaceSearchQuery },
                    set: { service.panelController.setWorkspaceSearchQuery($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                Task { @MainActor in
                    await service.performWorkspaceSearch()
                }
            }

            AppButton(String(localized: "Search", bundle: .module), systemImage: "magnifyingglass", style: .primary, size: .small) {
                Task { @MainActor in
                    await service.performWorkspaceSearch()
                }
            }
            .disabled(service.panelState.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            AppButton(String(localized: "Open Search Editor", bundle: .module), systemImage: "doc.text.magnifyingglass", style: .secondary, size: .small) {
                service.openWorkspaceSearchResultsInEditor()
            }
            .disabled(service.panelState.workspaceSearchResults.isEmpty)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if service.panelState.isWorkspaceSearchLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text(String(localized: "Searching workspace…", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = service.panelState.workspaceSearchErrorMessage {
            emptyState(error, systemImage: "exclamationmark.triangle")
        } else if service.panelState.workspaceSearchQuery.isEmpty {
            emptyState(String(localized: "Enter a query and press Return", bundle: .module), systemImage: "magnifyingglass")
        } else if service.panelState.workspaceSearchResults.isEmpty {
            emptyState(String(localized: "No results", bundle: .module), systemImage: "doc.text.magnifyingglass")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let summary = service.panelState.workspaceSearchSummary {
                        Text(String(localized: "\(summary.totalMatches) matches in \(summary.totalFiles) files", bundle: .module))
                            .font(.appMicroEmphasized)
                            .foregroundColor(theme.textSecondary)
                    }

                    ForEach(service.panelState.workspaceSearchResults) { file in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                service.panelController.toggleWorkspaceSearchFileCollapse(path: file.path)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isCollapsed(file) ? "chevron.right" : "chevron.down")
                                        .font(.appMicroEmphasized)
                                        .foregroundColor(theme.textSecondary)

                                    Text(file.path)
                                        .font(.appCaptionEmphasized)
                                        .foregroundColor(theme.textPrimary)

                                    Spacer()

                                    Text(fileMatchSummary(file))
                                        .font(.appMicroEmphasized)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed(file) {
                                ForEach(file.matches) { match in
                                    Button {
                                        service.openWorkspaceSearchMatch(match)
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("L\(match.line):C\(match.column)")
                                                .font(.appMonoMicro)
                                                .foregroundColor(theme.textSecondary)
                                                .frame(width: 62, alignment: .leading)

                                            Text(match.preview)
                                                .font(.appMonoCaption)
                                                .foregroundColor(theme.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .appSurface(style: .custom(rowBackground(for: match)), cornerRadius: 8, borderColor: rowBorder(for: match))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(10)
                        .appSurface(style: .custom(theme.textPrimary.opacity(0.035)), cornerRadius: 10)
                    }
                }
                .padding(10)
            }
        }
    }

    private func isCollapsed(_ file: EditorWorkspaceSearchFileResult) -> Bool {
        service.panelState.workspaceSearchCollapsedFilePaths.contains(file.path)
    }

    private func fileMatchSummary(_ file: EditorWorkspaceSearchFileResult) -> String {
        let noun = file.matchCount == 1
            ? String(localized: "match", bundle: .module)
            : String(localized: "matches", bundle: .module)
        return "\(file.matchCount) \(noun)"
    }

    private func rowBackground(for match: EditorWorkspaceSearchMatch) -> Color {
        service.panelState.selectedWorkspaceSearchMatchID == match.id
            ? theme.textPrimary.opacity(0.1)
            : theme.textPrimary.opacity(0.05)
    }

    private func rowBorder(for match: EditorWorkspaceSearchMatch) -> Color {
        service.panelState.selectedWorkspaceSearchMatchID == match.id
            ? theme.textPrimary.opacity(0.18)
            : .clear
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.appTitle)
                .foregroundColor(theme.textSecondary)
            Text(title)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
