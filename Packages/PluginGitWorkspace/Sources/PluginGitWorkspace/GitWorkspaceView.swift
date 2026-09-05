import GitPlugin
import ProviderProject
import SwiftUI

@MainActor
private final class GitWorkspaceProjectObserver: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ProjectProvidingObserverHandle)?

    init(project: any ProjectProviding) {
        handle = project.addObserver { [weak self] event in
            guard case .currentProjectChanged = event else { return }
            self?.revision += 1
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}

/// Git 工作区主面板：当前仓库概览、工作区状态和最近提交。
public struct GitWorkspaceView: View {
    let project: any ProjectProviding
    @StateObject private var projectObserver: GitWorkspaceProjectObserver
    @State private var status: GitStatus?
    @State private var commits: [GitCommitLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(project: any ProjectProviding) {
        self.project = project
        _projectObserver = StateObject(wrappedValue: GitWorkspaceProjectObserver(project: project))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if project.currentProject == nil {
                emptyState(
                    icon: "folder",
                    title: "Select a Project",
                    message: "Choose a project to view its Git history and working tree."
                )
            } else if isLoading && status == nil && commits.isEmpty {
                ProgressView("Loading Git status…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, status == nil && commits.isEmpty {
                emptyState(icon: "exclamationmark.triangle", title: "Unable to Load Git", message: errorMessage)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        statusSection
                        workingTreeSection
                        commitsSection
                    }
                    .padding(24)
                    .frame(maxWidth: 980, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: reloadKey) {
            await reload()
        }
    }

    private var reloadKey: String {
        "\(projectObserver.revision):\(project.currentProject?.path ?? "")"
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.currentProject?.name ?? "Git Workspace")
                    .font(.headline)
                Text(project.currentProject?.path ?? "No project selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await reload(force: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(project.currentProject == nil || isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let status {
            VStack(alignment: .leading, spacing: 10) {
                Text("Repository Status")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    statusCard("Branch", value: status.branch.isEmpty ? "Detached HEAD" : status.branch, icon: "arrow.triangle.branch")
                    statusCard("Staged", value: "\(status.staged.count)", icon: "checkmark.circle")
                    statusCard("Changes", value: "\(workingTreeFileCount(status))", icon: "pencil.circle")
                    statusCard("Remote", value: status.remote ?? "None", icon: "cloud")
                }
            }
        }
    }

    private func statusCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var workingTreeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Working Tree", count: workingTreeFiles.count)
            if workingTreeFiles.isEmpty {
                Label("Working tree is clean", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(workingTreeFiles, id: \.self) { file in
                        HStack(spacing: 8) {
                            Text(changeLabel(for: file))
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(changeColor(for: file))
                                .frame(width: 20)
                            Text(file)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        Divider()
                    }
                }
                .padding(.horizontal, 12)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Recent Commits", count: commits.count)
            if commits.isEmpty {
                Text("No commits yet.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(commits, id: \.hash) { commit in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(commit.message)
                                .font(.body.weight(.medium))
                                .lineLimit(2)
                            HStack(spacing: 8) {
                                Text(String(commit.hash.prefix(7)))
                                    .font(.system(.caption, design: .monospaced))
                                Text(commit.author)
                                Text(commit.date)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        Divider()
                    }
                }
                .padding(.horizontal, 12)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
    }

    private var workingTreeFiles: [String] {
        guard let status else { return [] }
        return Array(Set(status.modified + status.added + status.deleted + status.renamed + status.staged)).sorted()
    }

    private func workingTreeFileCount(_ status: GitStatus) -> Int {
        Set(status.modified + status.added + status.deleted + status.renamed + status.staged).count
    }

    private func changeLabel(for file: String) -> String {
        guard let status else { return "?" }
        if status.staged.contains(file) { return "S" }
        if status.added.contains(file) { return "A" }
        if status.deleted.contains(file) { return "D" }
        if status.renamed.contains(file) { return "R" }
        return "M"
    }

    private func changeColor(for file: String) -> Color {
        switch changeLabel(for: file) {
        case "A": return .green
        case "D": return .red
        case "R": return .blue
        case "S": return .purple
        default: return .orange
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func reload(force: Bool = false) async {
        guard let path = project.currentProject?.path, !path.isEmpty else {
            status = nil
            commits = []
            errorMessage = nil
            return
        }

        if !force && isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedStatus = GitService.shared.getStatus(path: path)
            async let loadedCommits = GitService.shared.getLog(path: path, count: 50, branch: nil, file: nil)
            status = try await loadedStatus
            commits = try await loadedCommits
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
