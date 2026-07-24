import LumiUI
import SuperLogKit
import SwiftUI
import LumiKernel

@MainActor
public struct RAGSettingsView: View, SuperLog {
    let kernel: LumiKernel
    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var loadError: String?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                if trackedProjects.isEmpty {
                    AppEmptyState(
                        icon: "folder.badge.questionmark",
                        title: LumiPluginLocalization.string("Please select or add a project first for RAG to build and display indexes.", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    if let loadError {
                        AppSettingSection(title: "Status", titleAlignment: .leading) {
                            VStack(spacing: 0) {
                                AppSettingRow(
                                    title: loadError,
                                    icon: "exclamationmark.triangle.fill"
                                ) {
                                    Button {
                                        Task { await loadStatus() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let runtimeInfo {
                        runtimeSection(runtimeInfo)
                    }

                    let projects = trackedProjects
                    ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                        projectSection(project)
                        if index < projects.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: trackedProjects.map(\.path).joined(separator: "|")) {
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            progressByPath[event.projectPath] = event
            if event.isFinished {
                Task { await loadStatus() }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func runtimeSection(_ info: RAGRuntimeInfo) -> some View {
        AppSettingSection(title: "Runtime", titleAlignment: .leading) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "Vector Backend",
                    icon: "cpu"
                ) {
                    Text(info.vectorBackend.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func projectSection(_ project: RAGTrackedProject) -> some View {
        AppSettingSection(
            title: project.name,
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "Path",
                    icon: "folder"
                ) {
                    Text(project.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(project.path)
                }
                Divider().padding(.vertical, 8)

                statusRow(for: project)
                Divider().padding(.vertical, 8)

                if let status = statusesByPath[project.path] {
                    AppSettingRow(
                        title: "Last Indexed",
                        icon: "clock"
                    ) {
                        Text(relativeDate(status.lastIndexedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Files",
                        icon: "doc"
                    ) {
                        Text("\(status.fileCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Chunks",
                        icon: "square.stack.3d.up"
                    ) {
                        Text("\(status.chunkCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Embedding",
                        description: "dim \(status.embeddingDimension)",
                        icon: "brain.head.profile"
                    ) {
                        Text(status.embeddingModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    AppSettingRow(
                        title: "Status",
                        icon: "ellipsis.circle"
                    ) {
                        Text("Loading…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    AppSettingRow(
                        title: "Status",
                        icon: "circle.dashed"
                    ) {
                        Text("Not indexed yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = progressByPath[project.path],
                   progress.totalFiles > 0,
                   !progress.isFinished {
                    Divider().padding(.vertical, 8)
                    AppSettingRow(
                        title: "Progress",
                        icon: "progress.indicator"
                    ) {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                                .frame(maxWidth: 160)
                            Text("\(progress.scannedFiles)/\(progress.totalFiles)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statusRow(for project: RAGTrackedProject) -> some View {
        if let progress = progressByPath[project.path], !progress.isFinished {
            AppSettingRow(
                title: "Status",
                icon: "arrow.triangle.2.circlepath"
            ) {
                statusPill(text: "Indexing", color: .blue, spinning: true)
            }
        } else if let status = statusesByPath[project.path] {
            if status.isStale {
                AppSettingRow(
                    title: "Status",
                    icon: "exclamationmark.triangle.fill"
                ) {
                    statusPill(text: "Outdated", color: .orange, spinning: false)
                }
            } else {
                AppSettingRow(
                    title: "Status",
                    icon: "checkmark.circle.fill"
                ) {
                    statusPill(text: "Up to Date", color: .green, spinning: false)
                }
            }
        } else if isLoading {
            AppSettingRow(
                title: "Status",
                icon: "ellipsis.circle"
            ) {
                statusPill(text: "Loading…", color: .secondary, spinning: false)
            }
        } else {
            AppSettingRow(
                title: "Status",
                icon: "circle.dashed"
            ) {
                statusPill(text: "Not Indexed", color: .secondary, spinning: false)
            }
        }
    }

    @ViewBuilder
    private func statusPill(text: String, color: Color, spinning: Bool) -> some View {
        HStack(spacing: 4) {
            if spinning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }
}

// MARK: - Load Status

extension RAGSettingsView {
    private func loadStatus() async {
        let projects = trackedProjects
        guard !projects.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = ProjectRAGPlugin.getService()
            runtimeInfo = try await service.getRuntimeInfo()

            var next: [String: RAGIndexStatus] = [:]
            for project in projects {
                if let status = try await service.getIndexStatus(projectPath: project.path) {
                    next[project.path] = status
                }
            }
            statusesByPath = next
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Helpers

extension RAGSettingsView {
    private var trackedProjects: [RAGTrackedProject] {
        let projects = (kernel.project?.projects ?? []).map {
            RAGTrackedProject(name: $0.name, path: $0.path)
        }
        let currentPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProject]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = RAGPluginRuntime.currentProjectName.isEmpty
                ? URL(fileURLWithPath: currentPath).lastPathComponent
                : RAGPluginRuntime.currentProjectName
            current = [RAGTrackedProject(name: name, path: currentPath)]
        }
        return dedupProjects(current + projects)
    }

    private func dedupProjects(_ projects: [RAGTrackedProject]) -> [RAGTrackedProject] {
        var seen = Set<String>()
        var result: [RAGTrackedProject] = []
        for project in projects {
            let normalized = URL(fileURLWithPath: project.path).standardizedFileURL.path
            guard !normalized.isEmpty else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(RAGTrackedProject(name: project.name, path: normalized))
        }
        return result
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct RAGTrackedProject: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
}