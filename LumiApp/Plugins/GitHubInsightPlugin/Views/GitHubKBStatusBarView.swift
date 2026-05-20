import SwiftUI
import LumiUI
import AppKit

/// View model that loads, syncs, and exposes GitHub ecosystem cache state for the UI.
@MainActor
final class GitHubKBStatusBarViewModel: ObservableObject {
    /// Current sync state displayed by the status bar and popover.
    @Published var state: GitHubInsightSyncState = .idle

    /// Cached entries for the active project.
    @Published var entries: [GitHubInsightKBEntry] = []

    /// Cached project profile for the active project.
    @Published var profile: GitHubInsightProjectProfile?

    /// Loads cached data and synchronizes the project cache when needed.
    func load(projectPath: String, force: Bool = false) {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            state = .idle
            entries = []
            profile = nil
            return
        }

        Task {
            if !force {
                await loadCache(projectPath: path)
            }

            state = .syncing
            let newState = await GitHubInsightSyncService.shared.syncIfNeeded(projectPath: path, force: force)
            state = newState
            await loadCache(projectPath: path)
        }
    }

    /// Loads only the persisted cache without triggering GitHub discovery.
    func loadCache(projectPath: String) async {
        guard let store = await GitHubInsightKnowledgeBaseManager.shared.loadStore(projectPath: projectPath) else {
            entries = []
            profile = nil
            if state != .syncing { state = .idle }
            return
        }
        entries = store.entries
        profile = store.profile
        if state != .syncing {
            state = .ready(count: store.entries.count)
        }
    }
}

/// Status bar entry that shows GitHub ecosystem cache state for the current project.
///
/// The view automatically attempts a cache sync when it appears, when the active
/// project changes, and when the application becomes active.
struct GitHubKBStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @StateObject private var viewModel = GitHubKBStatusBarViewModel()

    var body: some View {
        Group {
            if shouldShow {
                StatusBarHoverContainer(
                    detailView: GitHubKBPopover(viewModel: viewModel, projectPath: projectVM.currentProjectPath),
                    popoverWidth: 720,
                    id: "github-insight-kb"
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: iconName)
                            .font(.system(size: 10))
                        if let count = displayCount {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear { viewModel.load(projectPath: projectVM.currentProjectPath) }
        .onChange(of: projectVM.currentProjectPath) { _, newValue in
            viewModel.load(projectPath: newValue)
        }
        .onApplicationDidBecomeActive {
            viewModel.load(projectPath: projectVM.currentProjectPath)
        }
        .onReceive(NotificationCenter.default.publisher(for: .githubInsightDidSync)) { _ in
            Task { await viewModel.loadCache(projectPath: projectVM.currentProjectPath) }
        }
    }

    private var shouldShow: Bool {
        !projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && stateIsVisible
    }

    private var stateIsVisible: Bool {
        switch viewModel.state {
        case .idle:
            return !viewModel.entries.isEmpty
        default:
            return true
        }
    }

    private var iconName: String {
        switch viewModel.state {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .rateLimited, .failed: return "exclamationmark.triangle"
        default: return "network"
        }
    }

    private var displayCount: Int? {
        switch viewModel.state {
        case .idle:
            return viewModel.entries.isEmpty ? nil : viewModel.entries.count
        case .syncing:
            return nil
        case .ready(let count):
            return count
        case .rateLimited, .failed:
            return nil
        }
    }
}

/// Popover displaying cached GitHub ecosystem entries and manual sync controls.
struct GitHubKBPopover: View {
    @ObservedObject var viewModel: GitHubKBStatusBarViewModel

    /// Project path used when the user triggers a forced sync.
    let projectPath: String
    @State private var selectedRelation: GitHubInsightRelationType?

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            relationPicker
            entriesList
            footer
        }
        .padding(14)
        .frame(minWidth: 620, minHeight: 360)
    }

    /// Header showing the knowledge base title and project profile summary.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(primaryTextColor)
                Text(String(localized: "GitHub Ecosystem KB", table: "GitHubInsight"))
                    .font(.headline)
                    .foregroundColor(primaryTextColor)
                Spacer()
                Text("\(viewModel.entries.count)")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
            if let profile = viewModel.profile {
                Text(String(format: String(localized: "Profile: %@", table: "GitHubInsight"), profile.shortTitle))
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }
        }
    }

    /// Segmented control for filtering entries by relation type.
    private var relationPicker: some View {
        Picker("Relation", selection: Binding(
            get: { selectedRelation?.rawValue ?? "all" },
            set: { selectedRelation = $0 == "all" ? nil : GitHubInsightRelationType(rawValue: $0) }
        )) {
            Text(String(localized: "All", table: "GitHubInsight")).tag("all")
            ForEach(GitHubInsightRelationType.allCases, id: \.rawValue) { relation in
                Text(relation.title).tag(relation.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    /// Scrollable list of filtered knowledge base entries.
    private var entriesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if filteredEntries.isEmpty {
                    Text(emptyText)
                        .font(.callout)
                        .foregroundColor(secondaryTextColor)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(filteredEntries) { entry in
                        GitHubKBEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    /// Footer showing sync state and the manual refresh button.
    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundColor(secondaryTextColor)
            Spacer()
            Button {
                viewModel.load(projectPath: projectPath, force: true)
            } label: {
                Label(String(localized: "Sync Now", table: "GitHubInsight"), systemImage: "arrow.clockwise")
            }
        }
    }

    /// Entries filtered by the selected relation and sorted by relevance.
    private var filteredEntries: [GitHubInsightKBEntry] {
        viewModel.entries
            .filter { selectedRelation == nil || $0.relationType == selectedRelation }
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    /// Empty-state text based on the current sync state.
    private var emptyText: String {
        switch viewModel.state {
        case .syncing:
            return String(localized: "Syncing GitHub ecosystem references...", table: "GitHubInsight")
        default:
            return String(localized: "No cached GitHub ecosystem references yet.", table: "GitHubInsight")
        }
    }

    /// Human-readable sync status shown in the popover footer.
    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return String(localized: "Idle", table: "GitHubInsight")
        case .syncing:
            return String(localized: "Syncing", table: "GitHubInsight")
        case .ready(let count):
            return String(format: String(localized: "Ready: %lld entries", table: "GitHubInsight"), count)
        case .rateLimited:
            return String(localized: "GitHub rate limited", table: "GitHubInsight")
        case .failed(let message):
            return message
        }
    }
}

/// Row view for a single cached GitHub repository reference.
private struct GitHubKBEntryRow: View {
    /// Knowledge base entry rendered by this row.
    let entry: GitHubInsightKBEntry

    private var primaryTextColor: Color {
        Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
    }

    private var secondaryTextColor: Color {
        Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private var rowBackgroundColor: Color {
        Color.adaptive(light: "F5F5F7", dark: "1C1C1E")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                Text(entry.relationType.title)
                    .font(.caption2)
                    .foregroundColor(Color.adaptive(light: "FFFFFF", dark: "FFFFFF"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                Label("\(entry.stars)", systemImage: "star")
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
            }

            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(.caption)
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
            }

            if let insight = entry.keyInsights.first {
                Text(insight)
                    .font(.caption)
                    .foregroundColor(primaryTextColor.opacity(0.8))
                    .lineLimit(2)
            }

            HStack {
                Text(entry.language ?? "Unknown")
                    .font(.caption2)
                    .foregroundColor(secondaryTextColor)
                Spacer()
                Button {
                    if let url = URL(string: entry.repoURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("GitHub", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
            }
        }
        .padding(10)
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
