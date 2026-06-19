import SwiftUI
import SuperLogKit
import LumiCoreKit

@MainActor
public struct RAGSettingsPopoverView: View, SuperLog {
    public nonisolated static var emoji: String { "🦞" }
    public nonisolated static var verbose: Bool { false }
    @Environment(\.dismiss) private var dismiss

    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(LumiPluginLocalization.string("RAG Index Status", bundle: .module), systemImage: "doc.text.magnifyingglass")
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
                        Text(LumiPluginLocalization.string("No Projects", bundle: .module))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trackedProjects) { project in
                            projectRow(project)
                        }
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

// MARK: - Project Row

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
                    Label(status.isStale ? LumiPluginLocalization.string("Outdated", bundle: .module) : LumiPluginLocalization.string("Up to Date", bundle: .module), systemImage: status.isStale ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(status.isStale ? .orange : .green)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(LumiPluginLocalization.string("Not indexed yet", bundle: .module))
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

// MARK: - Private

extension RAGSettingsPopoverView {
    private var trackedProjects: [RAGTrackedProjectPopover] {
        let recent = RAGPluginRuntime.recentProjectsProvider().map { RAGTrackedProjectPopover(name: $0.name, path: $0.path) }
        let currentPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProjectPopover]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = RAGPluginRuntime.currentProjectName.isEmpty ? URL(fileURLWithPath: currentPath).lastPathComponent : RAGPluginRuntime.currentProjectName
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
        } catch {}
    }
}

private struct RAGTrackedProjectPopover: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
}
