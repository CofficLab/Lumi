import EditorService
import LumiUI
import SwiftUI
import LumiKernel

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
                LumiPluginLocalization.string("Search in files", bundle: .module),
                text: Binding(
                    get: { service.panel.panelState.workspaceSearchQuery },
                    set: { service.panel.panelController.setWorkspaceSearchQuery($0) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                Task { @MainActor in
                    await service.panel.performWorkspaceSearch()
                }
            }

            AppButton(LumiPluginLocalization.string("Search", bundle: .module), systemImage: "magnifyingglass", style: .primary, size: .small) {
                Task { @MainActor in
                    await service.panel.performWorkspaceSearch()
                }
            }
            .disabled(service.panel.panelState.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            AppButton(LumiPluginLocalization.string("Open Search Editor", bundle: .module), systemImage: "doc.text.magnifyingglass", style: .secondary, size: .small) {
                service.panel.openWorkspaceSearchResultsInEditor()
            }
            .disabled(service.panel.panelState.workspaceSearchResults.isEmpty)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if service.panel.panelState.isWorkspaceSearchLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text(LumiPluginLocalization.string("Searching workspace…", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = service.panel.panelState.workspaceSearchErrorMessage {
            emptyState(error, systemImage: "exclamationmark.triangle")
        } else if service.panel.panelState.workspaceSearchQuery.isEmpty {
            emptyState(LumiPluginLocalization.string("Enter a query and press Return", bundle: .module), systemImage: "magnifyingglass")
        } else if service.panel.panelState.workspaceSearchResults.isEmpty {
            emptyState(LumiPluginLocalization.string("No results", bundle: .module), systemImage: "doc.text.magnifyingglass")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let summary = service.panel.panelState.workspaceSearchSummary {
                        Text(LumiPluginLocalization.string("\(summary.totalMatches) matches in \(summary.totalFiles) files", bundle: .module))
                            .font(.appMicroEmphasized)
                            .foregroundColor(theme.textSecondary)
                    }

                    ForEach(service.panel.panelState.workspaceSearchResults) { file in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                service.panel.panelController.toggleWorkspaceSearchFileCollapse(path: file.path)
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
                                        service.panel.openWorkspaceSearchMatch(match)
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
        service.panel.panelState.workspaceSearchCollapsedFilePaths.contains(file.path)
    }

    private func fileMatchSummary(_ file: EditorWorkspaceSearchFileResult) -> String {
        let noun = file.matchCount == 1
            ? LumiPluginLocalization.string("match", bundle: .module)
            : LumiPluginLocalization.string("matches", bundle: .module)
        return "\(file.matchCount) \(noun)"
    }

    private func rowBackground(for match: EditorWorkspaceSearchMatch) -> Color {
        service.panel.panelState.selectedWorkspaceSearchMatchID == match.id
            ? theme.textPrimary.opacity(0.1)
            : theme.textPrimary.opacity(0.05)
    }

    private func rowBorder(for match: EditorWorkspaceSearchMatch) -> Color {
        service.panel.panelState.selectedWorkspaceSearchMatchID == match.id
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
