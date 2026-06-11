import LumiUI
import SuperLogKit
import SwiftUI
import LumiCoreKit

@MainActor
public struct RAGSettingsView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public nonisolated static var emoji: String { "🦞" }
    public nonisolated static var verbose: Bool { false }

    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var activeProjectActionPath: String?
    @State private var message: String?

    public init() {}

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("RAG 索引状态", bundle: .module),
            subtitle: LumiPluginLocalization.string("Manage semantic indexes for tracked projects.", bundle: .module),
            showHeader: false
        ) {
            actionsCard

            if trackedProjects.isEmpty {
                AppCard {
                    AppEmptyState(
                        icon: "folder.badge.questionmark",
                        title: LumiPluginLocalization.string("请先选择或添加项目，RAG 才能建立与展示索引。", bundle: .module)
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
                message = String(format: LumiPluginLocalization.string("Index update completed: %@", bundle: .module), event.projectPath)
                Task { await loadStatus() }
            }
        }
    }

    private var actionsCard: some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Actions", bundle: .module), spacing: 12) {
                HStack(spacing: 8) {
                    AppButton(
                        LumiPluginLocalization.string("刷新全部状态", bundle: .module),
                        style: .secondary,
                        fillsWidth: true
                    ) {
                        Task { await loadStatus() }
                    }
                    .disabled(isLoading)

                    AppButton(
                        LumiPluginLocalization.string("重建全部索引", bundle: .module),
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
            AppSettingsSection(title: LumiPluginLocalization.string("运行时", bundle: .module), spacing: 8) {
                GlassKeyValueRow(
                    label: LumiPluginLocalization.string("Vector Backend", bundle: .module),
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
                        label: LumiPluginLocalization.string("最近索引", bundle: .module),
                        value: relativeDate(status.lastIndexedAt)
                    )
                    GlassKeyValueRow(
                        label: LumiPluginLocalization.string("文件数", bundle: .module),
                        value: "\(status.fileCount)"
                    )
                    GlassKeyValueRow(
                        label: LumiPluginLocalization.string("片段数", bundle: .module),
                        value: "\(status.chunkCount)"
                    )
                    AppSettingsRow {
                        HStack {
                            Text(LumiPluginLocalization.string("状态", bundle: .module))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            GlassBadge(
                                text: LocalizedStringKey(
                                    status.isStale
                                        ? LumiPluginLocalization.string("已过期", bundle: .module)
                                        : LumiPluginLocalization.string("最新", bundle: .module)
                                ),
                                style: status.isStale ? .warning : .success
                            )
                        }
                    }
                } else if isLoading {
                    Text(LumiPluginLocalization.string("读取中…", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text(LumiPluginLocalization.string("尚未建立索引", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                    ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                    Text(String(format: LumiPluginLocalization.string("Progress: %lld/%lld", bundle: .module), progress.scannedFiles, progress.totalFiles))
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                HStack(spacing: 8) {
                    AppButton(LumiPluginLocalization.string("刷新", bundle: .module), style: .secondary, fillsWidth: true) {
                        Task { await refreshProjectStatus(projectPath: project.path) }
                    }
                    .disabled(isLoading)

                    AppButton(LumiPluginLocalization.string("重建", bundle: .module), style: .primary, fillsWidth: true) {
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
            message = String(format: LumiPluginLocalization.string("Failed to load index status: %@", bundle: .module), error.localizedDescription)
        }
    }

    private func rebuildIndex() async {
        let projects = trackedProjects
        guard !projects.isEmpty else { return }

        isLoading = true
        message = LumiPluginLocalization.string("Rebuilding all indexes...", bundle: .module)
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            for project in projects {
                try await service.ensureIndexed(projectPath: project.path, force: true)
            }
            await loadStatus()
            message = LumiPluginLocalization.string("All project indexes updated.", bundle: .module)
        } catch {
            message = String(format: LumiPluginLocalization.string("Failed to rebuild indexes: %@", bundle: .module), error.localizedDescription)
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
            message = String(format: LumiPluginLocalization.string("Refreshed: %@", bundle: .module), projectPath)
        } catch {
            message = String(format: LumiPluginLocalization.string("Refresh failed: %@", bundle: .module), error.localizedDescription)
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
            message = String(format: LumiPluginLocalization.string("Rebuilt: %@", bundle: .module), projectPath)
        } catch {
            message = String(format: LumiPluginLocalization.string("Rebuild failed: %@", bundle: .module), error.localizedDescription)
        }
    }
}

// MARK: - Helpers

extension RAGSettingsView {
    private var trackedProjects: [RAGTrackedProject] {
        let recent = RAGPluginRuntime.recentProjectsProvider().map { RAGTrackedProject(name: $0.name, path: $0.path) }
        let currentPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProject]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = RAGPluginRuntime.currentProjectName.isEmpty ? URL(fileURLWithPath: currentPath).lastPathComponent : RAGPluginRuntime.currentProjectName
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
    public var id: String { path }
    public let name: String
    public let path: String
}
