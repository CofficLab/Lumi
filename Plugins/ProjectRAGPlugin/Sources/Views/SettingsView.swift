import LumiUI
import SuperLogKit
import SwiftUI
import LumiKernel
import AppKit
import os

@MainActor
public struct RAGSettingsView: View, SuperLog {
    public nonisolated static let emoji = ProjectRAGPlugin.emoji
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project.rag")

    @ObservedObject private var kernel: LumiKernel
    @LumiTheme private var theme
    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var isIndexingPaused = false
    @State private var isUpdatingPauseState = false
    @State private var loadError: String?
    @State private var selectedProjectPath: String?

    public init(kernel: LumiKernel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Project RAG", bundle: .module),
            subtitle: LumiPluginLocalization.string("Enable natural language queries over your project codebase using a vector database.", bundle: .module),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                header

                if trackedProjects.isEmpty {
                    AppEmptyState(
                        icon: "folder.badge.questionmark",
                        title: LumiPluginLocalization.string("Please select or add a project first for RAG to build and display indexes.", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        projectSidebar
                            .frame(width: 320)
                            .frame(maxHeight: .infinity)

                        AppDivider(.vertical)

                        projectDetail
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(theme.divider, lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task(id: trackedProjects.map(\.path).joined(separator: "|")) {
            syncSelection()
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            progressByPath[event.projectPath] = event
            if event.isFinished {
                Task { await loadStatus() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(
                "\(trackedProjects.count) projects",
                systemImage: "folder"
            )
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            Spacer()
            AppButton(
                isIndexingPaused
                    ? LumiPluginLocalization.string("Resume Indexing", bundle: .module)
                    : LumiPluginLocalization.string("Pause Indexing", bundle: .module),
                systemImage: isIndexingPaused ? "play.fill" : "pause.fill",
                size: .small
            ) {
                toggleIndexingPause()
            }
            .disabled(isUpdatingPauseState)
            AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                Task { await loadStatus() }
            }
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var projectSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Projects", systemImage: "folder.fill")
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.background)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(trackedProjects) { project in
                        projectRow(project)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: .infinity)
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func projectRow(_ project: RAGTrackedProject) -> some View {
        let isSelected = selectedProjectPath == project.path
        let status = statusesByPath[project.path]
        let isIndexing = progressByPath[project.path].map { !$0.isFinished } ?? false

        return AppListRow(isSelected: isSelected, action: {
            selectedProjectPath = project.path
        }) {
            HStack(spacing: 10) {
                Image(systemName: isIndexing ? "arrow.triangle.2.circlepath" : "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(statusColor(status: status, isIndexing: isIndexing))
                    .frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private var projectDetail: some View {
        if let project = trackedProjects.first(where: { $0.path == selectedProjectPath }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let loadError {
                        AppSettingSection(title: LumiPluginLocalization.string("Status", bundle: .module), titleAlignment: .leading) {
                            AppSettingRow(title: loadError, icon: "exclamationmark.triangle.fill") {
                                Button {
                                    Task { await loadStatus() }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    RAGSettingsProjectSectionView(
                        project: project,
                        statusesByPath: statusesByPath,
                        progressByPath: progressByPath,
                        isLoading: isLoading
                    )

                    if let runtimeInfo {
                        runtimeSection(runtimeInfo)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(icon: "folder", title: "Select a project")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    private func syncSelection() {
        if selectedProjectPath == nil || !trackedProjects.contains(where: { $0.path == selectedProjectPath }) {
            selectedProjectPath = trackedProjects.first?.path
        }
    }

    private func statusColor(status: RAGIndexStatus?, isIndexing: Bool) -> Color {
        if isIndexing { return .blue }
        if status?.isStale == true { return .orange }
        if status != nil { return .green }
        return .secondary
    }

    // MARK: - Sections

    @ViewBuilder
    private func runtimeSection(_ info: RAGRuntimeInfo) -> some View {
        AppSettingSection(title: LumiPluginLocalization.string("Runtime", bundle: .module), titleAlignment: .leading) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: LumiPluginLocalization.string("Vector Backend", bundle: .module),
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
            isIndexingPaused = await service.isIndexingPaused()
            if Self.verbose {
                Self.logger.info("\(Self.t)Settings loadStatus begin projects=\(projects.count) initialized=\(service.isInitialized) paused=\(isIndexingPaused)")
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

    private func toggleIndexingPause() {
        guard !isUpdatingPauseState else { return }
        isUpdatingPauseState = true
        let shouldPause = !isIndexingPaused

        Task { @MainActor in
            defer { isUpdatingPauseState = false }
            await ProjectRAGOnReadyHook().setIndexingPaused(shouldPause, kernel: kernel)
            let service = ProjectRAGPlugin.getService()
            isIndexingPaused = await service.isIndexingPaused()
            if shouldPause {
                progressByPath.removeAll()
            }
            await loadStatus()
        }
    }
}

// MARK: - Helpers

extension RAGSettingsView {
    private var trackedProjects: [RAGTrackedProject] {
        let projects = (kernel.project?.projects ?? []).map {
            RAGTrackedProject(name: $0.name, path: $0.path)
        }
        return dedupProjects(projects)
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

    /// 在 Finder 中打开本插件的磁盘数据目录(RAG 数据库所在位置)。
    private func openDataDirectory() {
        let url = kernel.storage?.pluginDataDirectory(for: "RAG")
            ?? RAGPluginRuntime.databaseDirectoryProvider()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
