import SwiftUI
import RAGKit

@MainActor
struct RAGSettingsView: View, SuperLog {
    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { true }

    @EnvironmentObject private var projectVM: WindowProjectVM
    private let recentProjectsStore = RecentProjectsStore()

    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var activeProjectActionPath: String?
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "RAG 索引状态", table: "RAG"))
                    .font(.headline)
                Spacer()
                Button(String(localized: "刷新全部状态", table: "RAG")) {
                    Task { await loadStatus() }
                }
                .disabled(isLoading)

                Button(String(localized: "重建全部索引", table: "RAG")) {
                    Task { await rebuildIndex() }
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if trackedProjects.isEmpty {
                        Text(String(localized: "请先选择或添加项目，RAG 才能建立与展示索引。", table: "RAG"))
                            .foregroundStyle(.secondary)
                    } else {
                        if let runtimeInfo {
                            runtimeSummary(runtimeInfo)
                        }

                        ForEach(trackedProjects) { project in
                            projectCard(project)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
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
}

// MARK: - View

extension RAGSettingsView {
    @ViewBuilder
    private func runtimeSummary(_ info: RAGRuntimeInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "运行时", table: "RAG"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            Text(String(format: String(localized: "Vector Backend: %@", table: "RAG"), info.vectorBackend.rawValue))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func projectCard(_ project: RAGTrackedProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(project.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let status = statusesByPath[project.path] {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text(String(localized: "最近索引", table: "RAG")).foregroundStyle(.secondary)
                        Text(relativeDate(status.lastIndexedAt))
                    }
                    GridRow {
                        Text(String(localized: "文件数", table: "RAG")).foregroundStyle(.secondary)
                        Text("\(status.fileCount)")
                    }
                    GridRow {
                        Text(String(localized: "片段数", table: "RAG")).foregroundStyle(.secondary)
                        Text("\(status.chunkCount)")
                    }
                    GridRow {
                        Text(String(localized: "状态", table: "RAG")).foregroundStyle(.secondary)
                        Text(status.isStale ? String(localized: "已过期", table: "RAG") : String(localized: "最新", table: "RAG"))
                            .foregroundStyle(status.isStale ? .orange : .green)
                    }
                }
            } else if isLoading {
                Text(String(localized: "读取中…", table: "RAG"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(String(localized: "尚未建立索引", table: "RAG"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                Text(String(format: String(localized: "Progress: %lld/%lld", table: "RAG"), progress.scannedFiles, progress.totalFiles))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(String(localized: "刷新", table: "RAG")) {
                    Task { await refreshProjectStatus(projectPath: project.path) }
                }
                .disabled(isLoading)

                Button(String(localized: "重建", table: "RAG")) {
                    Task { await rebuildProjectIndex(projectPath: project.path) }
                }
                .disabled(isLoading)

                if activeProjectActionPath == project.path {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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
