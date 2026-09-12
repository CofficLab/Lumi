import GitPlugin
import ProviderGitRepositoryWatch
import ProviderProject
import SwiftUI

@MainActor
private final class GitWorkspaceProjectObserver: ObservableObject {
    @Published private(set) var revision = 0
    private var projectHandle: (any ProjectProvidingObserverHandle)?
    private var gitWatchHandle: (any GitRepositoryWatchingObserverHandle)?

    init(project: any ProjectProviding, gitWatch: (any GitRepositoryWatching)?) {
        projectHandle = project.addObserver { [weak self] event in
            guard case .currentProjectChanged = event else { return }
            self?.revision += 1
        }
        gitWatchHandle = gitWatch?.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }

    func cancel() {
        projectHandle?.cancel()
        projectHandle = nil
        gitWatchHandle?.cancel()
        gitWatchHandle = nil
    }
}

/// Git 工作区主面板：当前仓库概览、工作区状态和最近提交。
public struct GitWorkspaceView: View {
    let project: any ProjectProviding
    @StateObject private var projectObserver: GitWorkspaceProjectObserver
    @StateObject private var viewModel: GitWorkspaceViewModel

    public init(project: any ProjectProviding, gitWatch: (any GitRepositoryWatching)? = nil) {
        self.project = project
        _projectObserver = StateObject(
            wrappedValue: GitWorkspaceProjectObserver(project: project, gitWatch: gitWatch)
        )
        _viewModel = StateObject(wrappedValue: GitWorkspaceViewModel(git: LiveGitWorkspaceGitProvider()))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if project.currentProject == nil {
                emptyState(
                    icon: "folder",
                    title: String(localized: "Select a Project", bundle: .module),
                    message: String(localized: "Choose a project to view its Git history and working tree.", bundle: .module)
                )
            } else if viewModel.isLoading && viewModel.status == nil && viewModel.commits.isEmpty {
                ProgressView(String(localized: "Loading Git status…", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.status == nil && viewModel.commits.isEmpty {
                emptyState(
                    icon: "exclamationmark.triangle",
                    title: String(localized: "Unable to Load Git", bundle: .module),
                    message: errorMessage
                )
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
            await viewModel.reload(path: project.currentProject?.path)
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
                Text(project.currentProject?.name ?? String(localized: "Git Workspace", bundle: .module))
                    .font(.headline)
                Text(project.currentProject?.path ?? String(localized: "No project selected", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                Task { await viewModel.reload(path: project.currentProject?.path, force: true) }
            } label: {
                Label(String(localized: "Refresh", bundle: .module), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(project.currentProject == nil || viewModel.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let status = viewModel.status {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Repository Status", bundle: .module))
                    .font(.title3.weight(.semibold))
                HStack(spacing: 12) {
                    statusCard(
                        String(localized: "Branch", bundle: .module),
                        value: status.branch.isEmpty
                            ? String(localized: "Detached HEAD", bundle: .module)
                            : status.branch,
                        icon: "arrow.triangle.branch"
                    )
                    statusCard(
                        String(localized: "Staged", bundle: .module),
                        value: "\(status.staged.count)",
                        icon: "checkmark.circle"
                    )
                    statusCard(
                        String(localized: "Changes", bundle: .module),
                        value: "\(viewModel.workingTreeFiles.count)",
                        icon: "pencil.circle"
                    )
                    statusCard(
                        String(localized: "Remote", bundle: .module),
                        value: status.remote ?? String(localized: "None", bundle: .module),
                        icon: "cloud"
                    )
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
            sectionTitle(String(localized: "Working Tree", bundle: .module), count: viewModel.workingTreeFiles.count)
            if viewModel.workingTreeFiles.isEmpty {
                Label(String(localized: "Working tree is clean", bundle: .module), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.workingTreeFiles, id: \.self) { file in
                        HStack(spacing: 8) {
                            Text(viewModel.changeLabel(for: file))
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
            sectionTitle(String(localized: "Recent Commits", bundle: .module), count: viewModel.commits.count)
            if viewModel.commits.isEmpty {
                Text(String(localized: "No commits yet.", bundle: .module))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.commits, id: \.hash) { commit in
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

    private func changeColor(for file: String) -> Color {
        switch viewModel.changeLabel(for: file) {
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

}
