import SwiftUI
import LumiUI

/// 启动器搜索面板视图（悬浮窗口内容）
public struct LauncherView: View {
    @ObservedObject private var searchModel = LauncherSearchModel.shared
    @ObservedObject private var appSearch = AppSearchService.shared

    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            searchHeader
            if !searchModel.results.isEmpty || isFileSearching {
                Divider()
                resultsSection
            } else if !searchModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Divider()
                emptyView
                    .frame(height: 88)
            } else {
                Divider()
                hintView
                    .frame(height: 88)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            isInputFocused = true
        }
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
    }

    private var isFileSearching: Bool {
        !searchModel.results.isEmpty && FileSearchService.shared.isSearching
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 20)

            TextField(
                LumiPluginLocalization.string("Search apps, files, commands, or type ? to ask AI...", bundle: .module),
                text: $searchModel.query
            )
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .focused($isInputFocused)
            .onSubmit {
                executeSelected()
            }
            .overlay(
                Group {
                    if appSearch.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                    }
                }
            )

            Text(verbatim: "⌥Space")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            closeButton
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(LumiPluginLocalization.string("Close", bundle: .module))
        .accessibilityLabel(LumiPluginLocalization.string("Close", bundle: .module))
    }

    // MARK: - Results

    private var resultsSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(LauncherResultKind.allCases, id: \.self) { kind in
                    let items = results(for: kind)
                    if !items.isEmpty {
                        Section {
                            ForEach(Array(items.enumerated()), id: \.element.id) { _, result in
                                LauncherResultRow(
                                    result: result,
                                    isSelected: flattenedIndex(of: result) == searchModel.selectedIndex
                                )
                                .onTapGesture {
                                    selectAndExecute(result)
                                }
                                .onHover { hovering in
                                    if hovering, let index = flattenedIndex(of: result), index != searchModel.selectedIndex {
                                        searchModel.selectedIndex = index
                                    }
                                }
                            }
                        } header: {
                            LauncherSectionHeader(
                                title: kind.localizedTitle,
                                systemImage: kind.systemImage
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text(LumiPluginLocalization.string("No matching results", bundle: .module))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hintView: some View {
        VStack(spacing: 8) {
            Text(LumiPluginLocalization.string("Type to search apps, files and commands", bundle: .module))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(LumiPluginLocalization.string("Prefix with ? to ask Lumi directly", bundle: .module))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func results(for kind: LauncherResultKind) -> [LauncherResult] {
        searchModel.results.filter { $0.kind == kind }
    }

    private func flattenedIndex(of result: LauncherResult) -> Int? {
        searchModel.results.firstIndex(where: { $0.id == result.id })
    }

    private func selectAndExecute(_ result: LauncherResult) {
        guard let index = flattenedIndex(of: result) else { return }
        searchModel.selectedIndex = index
        searchModel.execute(at: index)
        dismiss()
    }

    private func executeSelected() {
        if searchModel.execute(at: searchModel.selectedIndex) {
            dismiss()
        }
    }

    private func dismiss() {
        LauncherWindowController.shared.hide()
    }

    // MARK: - Keyboard

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .upArrow:
            if searchModel.selectedIndex > 0 {
                searchModel.selectedIndex -= 1
            }
            return .handled

        case .downArrow:
            if searchModel.selectedIndex < searchModel.results.count - 1 {
                searchModel.selectedIndex += 1
            }
            return .handled

        case .escape:
            dismiss()
            return .handled

        default:
            return .ignored
        }
    }
}

// MARK: - Section Header

private struct LauncherSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

// MARK: - Result Row

private struct LauncherResultRow: View {
    let result: LauncherResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        switch result.kind {
        case .app:
            if let app = result.app {
                Image(nsImage: AppSearchService.shared.icon(for: app))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        case .file:
            Image(systemName: result.file?.isDirectory == true ? "folder.fill" : "doc.fill")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
        case .command:
            Image(systemName: "command")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
        case .ai:
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.purple)
        }
    }
}
