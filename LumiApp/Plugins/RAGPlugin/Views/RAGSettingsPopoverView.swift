import SwiftUI
import MagicKit

@MainActor
struct RAGSettingsPopoverView: View, SuperLog {
    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject private var projectVM: ProjectVM
    @Environment(\.dismiss) private var dismiss
    private let recentProjectsStore = RecentProjectsStore()

    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("RAG 索引状态", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if trackedProjects.isEmpty {
                        Text("暂无项目")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trackedProjects) { project in
                            projectRow(project)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("刷新全部") {
                            Task { await loadStatus() }
                        }
                        .disabled(isLoading)

                        Button("重建全部") {
                            Task { await rebuildAll() }
                        }
                        .disabled(isLoading)
                    }

                    if isLoading {
                        ProgressView("处理中…")
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
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
}

extension RAGSettingsPopoverView {
    @ViewBuilder
    private func projectRow(_ project: RAGTrackedProjectPopover) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(project.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let status = statusesByPath[project.path] {
                HStack(spacing: 10) {
                    Label("\(status.fileCount)", systemImage: "doc")
                    Label("\(status.chunkCount)", systemImage: "square.stack.3d.up")
                    Label(status.isStale ? "已过期" : "最新", systemImage: status.isStale ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(status.isStale ? .orange : .green)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("尚未建立索引")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

extension RAGSettingsPopoverView {
    private var trackedProjects: [RAGTrackedProjectPopover] {
        let recent = recentProjectsStore.loadProjects().map { RAGTrackedProjectPopover(name: $0.name, path: $0.path) }
        let currentPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProjectPopover]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = projectVM.currentProjectName.isEmpty ? URL(fileURLWithPath: currentPath).lastPathComponent : projectVM.currentProjectName
            current = [RAGTrackedProjectPopover(name: name, path: currentPath)]
        }
        return dedupProjects(current + recent)
    }

    private func dedupProjects(_ projects: [RAGTrackedProjectPopover]) -> [RAGTrackedProjectPopover] {
        var seen = Set<String>()
        var result: [RAGTrackedProjectPopover] = []
        for project in projects {
            let normalized = URL(fileURLWithPath: project.path).standardizedFileURL.path
            guard !normalized.isEmpty else { continue }
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(RAGTrackedProjectPopover(name: project.name, path: normalized))
        }
        return result
    }

    private func loadStatus() async {
        let projects = trackedProjects
        guard !projects.isEmpty else {
            statusesByPath = [:]
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            try await service.initialize()
            var next: [String: RAGIndexStatus] = [:]
            for project in projects {
                if let status = try await service.getIndexStatus(projectPath: project.path) {
                    next[project.path] = status
                }
            }
            statusesByPath = next
            message = nil
        } catch {
            message = "读取索引状态失败：\(error.localizedDescription)"
        }
    }

    private func rebuildAll() async {
        let projects = trackedProjects
        guard !projects.isEmpty else { return }

        isLoading = true
        message = "正在重建全部索引..."
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            try await service.initialize()
            for project in projects {
                try await service.ensureIndexed(projectPath: project.path, force: true)
            }
            await loadStatus()
            message = "全部项目索引更新完成。"
        } catch {
            message = "重建索引失败：\(error.localizedDescription)"
        }
    }
}

private struct RAGTrackedProjectPopover: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
}
