import LumiUI
import SwiftUI
import KernelLumi

public struct BottomEditorWorkspaceSearchPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: BottomWorkspaceSearchViewModel
    public var showsToolbar: Bool = true

    public init(viewModel: BottomWorkspaceSearchViewModel, showsToolbar: Bool = true) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
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
                text: $viewModel.query
            )
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                viewModel.performSearch()
            }

            AppButton(LumiPluginLocalization.string("Search", bundle: .module), systemImage: "magnifyingglass", style: .primary, size: .small) {
                viewModel.performSearch()
            }
            .disabled(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            AppButton(LumiPluginLocalization.string("Open Search Editor", bundle: .module), systemImage: "doc.text.magnifyingglass", style: .secondary, size: .small) {
                viewModel.openResultsInEditor()
            }
            .disabled(viewModel.state.results.isEmpty)
        }
        .padding(10)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.state.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text(LumiPluginLocalization.string("Searching workspace…", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.state.errorMessage {
            emptyState(error, systemImage: "exclamationmark.triangle")
        } else if viewModel.query.isEmpty {
            emptyState(LumiPluginLocalization.string("Enter a query and press Return", bundle: .module), systemImage: "magnifyingglass")
        } else if viewModel.state.results.isEmpty {
            emptyState(LumiPluginLocalization.string("No results", bundle: .module), systemImage: "doc.text.magnifyingglass")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if let summary = viewModel.state.summary {
                        Text(LumiPluginLocalization.string("\(summary.totalMatches) matches in \(summary.totalFiles) files", bundle: .module))
                            .font(.appMicroEmphasized)
                            .foregroundColor(theme.textSecondary)
                    }

                    ForEach(viewModel.state.results) { file in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                viewModel.toggleFileCollapse(path: file.path)
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
                                        viewModel.openMatch(match)
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

    private func isCollapsed(_ file: EditorSearchFileResult) -> Bool {
        viewModel.collapsedFilePaths.contains(file.path)
    }

    private func fileMatchSummary(_ file: EditorSearchFileResult) -> String {
        let noun = file.matchCount == 1
            ? LumiPluginLocalization.string("match", bundle: .module)
            : LumiPluginLocalization.string("matches", bundle: .module)
        return "\(file.matchCount) \(noun)"
    }

    private func rowBackground(for match: EditorSearchMatch) -> Color {
        viewModel.selectedMatchID == match.id
            ? theme.textPrimary.opacity(0.1)
            : theme.textPrimary.opacity(0.05)
    }

    private func rowBorder(for match: EditorSearchMatch) -> Color {
        viewModel.selectedMatchID == match.id
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
