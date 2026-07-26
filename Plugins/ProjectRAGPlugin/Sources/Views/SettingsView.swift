import LumiUI
import SuperLogKit
import SwiftUI
import LumiKernel
import os

@MainActor
public struct RAGSettingsView: View, SuperLog {
    public nonisolated static let emoji = ProjectRAGPlugin.emoji
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project.rag")

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
                        RAGSettingsProjectSectionView(
                            project: project,
                            statusesByPath: statusesByPath,
                            progressByPath: progressByPath,
                            isLoading: isLoading
                        )
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
}

// MARK: - Load Status

extension RAGSettingsView {
    private func loadStatus() async {
        let projects = trackedProjects
        guard !projects.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)Settings loadStatus skipped: no tracked projects")
            }
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = ProjectRAGPlugin.getService()
            if Self.verbose {
                Self.logger.info("\(Self.t)Settings loadStatus begin projects=\(projects.count) initialized=\(service.isInitialized)")
            }
            try await service.initialize()
            if Self.verbose {
                Self.logger.info("\(Self.t)Settings service initialized=\(service.isInitialized)")
            }
            runtimeInfo = try await service.getRuntimeInfo()
            if Self.verbose, let runtimeInfo {
                Self.logger.info("\(Self.t)Settings runtime loaded backend=\(runtimeInfo.vectorBackend.rawValue)")
            }

            var next: [String: RAGIndexStatus] = [:]
            for project in projects {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Settings loading index status project=\(project.path)")
                }
                if let status = try await service.getIndexStatus(projectPath: project.path) {
                    next[project.path] = status
                    if Self.verbose {
                        Self.logger.info("\(Self.t)Settings status loaded project=\(project.path) files=\(status.fileCount) chunks=\(status.chunkCount) stale=\(status.isStale)")
                    }
                } else if Self.verbose {
                    Self.logger.info("\(Self.t)Settings status missing project=\(project.path)")
                }
            }
            statusesByPath = next
            loadError = nil
            if Self.verbose {
                Self.logger.info("\(Self.t)Settings loadStatus completed statuses=\(next.count)")
            }
        } catch {
            loadError = error.localizedDescription
            if Self.verbose {
                Self.logger.error("\(Self.t)Settings loadStatus failed initialized=\(ProjectRAGPlugin.getService().isInitialized) error=\(error.localizedDescription)")
            }
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
