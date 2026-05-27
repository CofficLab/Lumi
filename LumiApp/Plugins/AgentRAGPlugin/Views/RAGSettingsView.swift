import LumiUI
import RAGKit
import SwiftUI

@MainActor
struct RAGSettingsView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { true }

    @EnvironmentObject private var projectVM: WindowProjectVM
    private let recentProjectsStore = ProjectsStore()

    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var activeProjectActionPath: String?
    @State private var message: String?

    var body: some View {
        PluginSettingsScaffold(
            title: String(localized: "RAG 索引状态", table: "RAG"),
            subtitle: String(localized: "Manage semantic indexes for tracked projects.", table: "RAG"),
            showHeader: false
        ) {
            actionsCard

            if trackedProjects.isEmpty {
                AppCard {
                    AppEmptyState(
                        icon: "folder.badge.questionmark",
                        title: String(localized: "请先选择或添加项目，RAG 才能建立与展示索引。", table: "RAG")
                    )
                    .frame(minHeight: 160)
                }
            } else {
                if let runtimeInfo {
                    runtimeCard(runtimeInfo)
                }

                ForEach(trackedProjects) { project in
                    projectCard(project)
                }
            }

            if let message {
                AppErrorBanner(message: LocalizedStringKey(message))
            }
        }
        .task(id: trackedProjects.map(\.path).joined(separator: "|")) {
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            progressByPath[event.projectPath] = event
            if event.isFinished {
                message = String(format: String(localized: "Index update completed: %@", table: "RAG"), event.projectPath)
                Task { await loadStatus() }
            }
        }
    }

    private var actionsCard: some View {
        AppCard {
            AppSettingsSection(title: String(localized: "Actions", table: "RAG"), spacing: 12) {
                HStack(spacing: 8) {
                    AppButton(
                        String(localized: "刷新全部状态", table: "RAG"),
                        style: .secondary,
                        fillsWidth: true
                    ) {
                        Task { await loadStatus() }
                    }
                    .disabled(isLoading)

                    AppButton(
                        String(localized: "重建全部索引", table: "RAG"),
                        style: .primary,
                        fillsWidth: true
                    ) {
                        Task { await rebuildIndex() }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private func runtimeCard(_ info: RAGRuntimeInfo) -> some View {
        AppCard {
            AppSettingsSection(title: String(localized: "运行时", table: "RAG"), spacing: 8) {
                GlassKeyValueRow(
                    label: String(localized: "Vector Backend", table: "RAG"),
                    value: info.vectorBackend.rawValue
                )
            }
        }
    }

    @ViewBuilder
    private func projectCard(_ project: RAGTrackedProject) -> some View {
        AppCard {
            AppSettingsSection(title: project.name, subtitle: project.path, spacing: 12) {
                if let status = statusesByPath[project.path] {
                    GlassKeyValueRow(
                        label: String(localized: "最近索引", table: "RAG"),
                        value: relativeDate(status.lastIndexedAt)
                    )
                    GlassKeyValueRow(
                        label: String(localized: "文件数", table: "RAG"),
                        value: "\(status.fileCount)"
                    )
                    GlassKeyValueRow(
                        label: String(localized: "片段数", table: "RAG"),
                        value: "\(status.chunkCount)"
                    )
                    AppSettingsRow {
                        HStack {
                            Text(String(localized: "状态", table: "RAG"))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            GlassBadge(
                                text: LocalizedStringKey(
                                    status.isStale
                                        ? String(localized: "已过期", table: "RAG")
                                        : String(localized: "最新", table: "RAG")
                                ),
                                style: status.isStale ? .warning : .success
                            )
                        }
                    }
                } else if isLoading {
                    Text(String(localized: "读取中…", table: "RAG"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text(String(localized: "尚未建立索引", table: "RAG"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                    ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                    Text(String(format: String(localized: "Progress: %lld/%lld", table: "RAG"), progress.scannedFiles, progress.totalFiles))
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                HStack(spacing: 8) {
                    AppButton(String(localized: "刷新", table: "RAG"), style: .secondary, fillsWidth: true) {
                        Task { await refreshProjectStatus(projectPath: project.path) }
                    }
                    .disabled(isLoading)

                    AppButton(String(localized: "重建", table: "RAG"), style: .primary, fillsWidth: true) {
                        Task { await rebuildProjectIndex(projectPath: project.path) }
                    }
                    .disabled(isLoading)

                    if activeProjectActionPath == project.path {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Action

extension RAGSettingsView {
    private func loadStatus() async {
        let projects = trackedProjects
        guard !projects.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            runtimeInfo = try await service.getRuntimeInfo()

            var next: [String: RAGIndexStatus] = [:]
            for project in projects {
                if let status = try await service.getIndexStatus(projectPath: project.path) {
                    next[project.path] = status
                }
            }
            statusesByPath = next
            message = nil
        } catch {
            message = String(format: String(localized: "Failed to load index status: %@", table: "RAG"), error.localizedDescription)
        }
    }

    private func rebuildIndex() async {
        let projects = trackedProjects
        guard !projects.isEmpty else { return }

        isLoading = true
        message = String(localized: "Rebuilding all indexes...", table: "RAG")
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            for project in projects {
                try await service.ensureIndexed(projectPath: project.path, force: true)
            }
            await loadStatus()
            message = String(localized: "All project indexes updated.", table: "RAG")
        } catch {
            message = String(format: String(localized: "Failed to rebuild indexes: %@", table: "RAG"), error.localizedDescription)
        }
    }

    private func refreshProjectStatus(projectPath: String) async {
        activeProjectActionPath = projectPath
        defer { activeProjectActionPath = nil }
        do {
            let service = RAGPlugin.getService()
            let status = try await service.getIndexStatus(projectPath: projectPath)
            statusesByPath[projectPath] = status
            if status == nil {
                statusesByPath.removeValue(forKey: projectPath)
            }
            message = String(format: String(localized: "Refreshed: %@", table: "RAG"), projectPath)
        } catch {
            message = String(format: String(localized: "Refresh failed: %@", table: "RAG"), error.localizedDescription)
        }
    }

    private func rebuildProjectIndex(projectPath: String) async {
        activeProjectActionPath = projectPath
        defer { activeProjectActionPath = nil }
        do {
            let service = RAGPlugin.getService()
            try await service.ensureIndexed(projectPath: projectPath, force: true)
            let status = try await service.getIndexStatus(projectPath: projectPath)
            statusesByPath[projectPath] = status
            message = String(format: String(localized: "Rebuilt: %@", table: "RAG"), projectPath)
        } catch {
            message = String(format: String(localized: "Rebuild failed: %@", table: "RAG"), error.localizedDescription)
        }
    }
}

// MARK: - Helpers

extension RAGSettingsView {
    private var trackedProjects: [RAGTrackedProject] {
        let recent = recentProjectsStore.loadProjects().map { RAGTrackedProject(name: $0.name, path: $0.path) }
        let currentPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProject]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = projectVM.currentProjectName.isEmpty ? URL(fileURLWithPath: currentPath).lastPathComponent : projectVM.currentProjectName
            current = [RAGTrackedProject(name: name, path: currentPath)]
        }
        return dedupProjects(current + recent)
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
    var id: String { path }
    let name: String
    let path: String
}
