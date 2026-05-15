import SwiftUI
import AppKit

@MainActor
final class GitHubKBStatusBarViewModel: ObservableObject {
    @Published var state: GitHubInsightSyncState = .idle
    @Published var entries: [GitHubInsightKBEntry] = []
    @Published var profile: GitHubInsightProjectProfile?

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

struct GitHubKBStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @StateObject private var viewModel = GitHubKBStatusBarViewModel()

    var body: some View {
        Group {
            if shouldShow {
                StatusBarHoverContainer(
                    detailView: GitHubKBPopover(viewModel: viewModel, projectPath: projectVM.currentProjectPath),
                    popoverWidth: 720,
                    id: "github-insight-kb"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: iconName)
                            .font(.system(size: 10))
                        Text(label)
                            .font(.system(size: 11))
                            .lineLimit(1)
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

    private var label: String {
        switch viewModel.state {
        case .idle:
            return viewModel.entries.isEmpty ? "GitHub KB" : "\(viewModel.entries.count) insights"
        case .syncing:
            return "Syncing..."
        case .ready(let count):
            return "\(count) insights"
        case .rateLimited:
            return "Rate limited"
        case .failed:
            return "Insight error"
        }
    }
}

struct GitHubKBPopover: View {
    @ObservedObject var viewModel: GitHubKBStatusBarViewModel
    let projectPath: String
    @State private var selectedRelation: GitHubInsightRelationType?

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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "network")
                Text("GitHub Ecosystem KB")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let profile = viewModel.profile {
                Text("Profile: \(profile.shortTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var relationPicker: some View {
        Picker("Relation", selection: Binding(
            get: { selectedRelation?.rawValue ?? "all" },
            set: { selectedRelation = $0 == "all" ? nil : GitHubInsightRelationType(rawValue: $0) }
        )) {
            Text("All").tag("all")
            ForEach(GitHubInsightRelationType.allCases, id: \.rawValue) { relation in
                Text(relation.title).tag(relation.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    private var entriesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if filteredEntries.isEmpty {
                    Text(emptyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ForEach(filteredEntries) { entry in
                        GitHubKBEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                viewModel.load(projectPath: projectPath, force: true)
            } label: {
                Label("Sync Now", systemImage: "arrow.clockwise")
            }
        }
    }

    private var filteredEntries: [GitHubInsightKBEntry] {
        viewModel.entries
            .filter { selectedRelation == nil || $0.relationType == selectedRelation }
            .sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private var emptyText: String {
        switch viewModel.state {
        case .syncing:
            return "Syncing GitHub ecosystem references..."
        default:
            return "No cached GitHub ecosystem references yet."
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle:
            return "Idle"
        case .syncing:
            return "Syncing"
        case .ready(let count):
            return "Ready: \(count) entries"
        case .rateLimited:
            return "GitHub rate limited"
        case .failed(let message):
            return message
        }
    }
}

private struct GitHubKBEntryRow: View {
    let entry: GitHubInsightKBEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.fullName)
                    .font(.system(size: 13, weight: .semibold))
                Text(entry.relationType.title)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                Label("\(entry.stars)", systemImage: "star")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !entry.description.isEmpty {
                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let insight = entry.keyInsights.first {
                Text(insight)
                    .font(.caption)
                    .lineLimit(2)
            }

            HStack {
                Text(entry.language ?? "Unknown")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
