import LumiUI
import SuperLogKit
import SwiftUI
import LumiKernel

@MainActor
public struct RAGSettingsView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing
    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    @State private var isLoading = false
    @State private var loadError: String?


    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }


    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("RAG Index Status", bundle: .module),
            subtitle: LumiPluginLocalization.string("Manage semantic indexes for tracked projects.", bundle: .module),
            showHeader: false
        ) {
            if let loadError {
                errorBanner(loadError)
            }
            if trackedProjects.isEmpty {
                AppCard {
                    AppEmptyState(
                        icon: "folder.badge.questionmark",
                        title: LumiPluginLocalization.string("Please select or add a project first for RAG to build and display indexes.", bundle: .module)
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


    // MARK: - Cards


    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(theme.error)
                Text(message)
                    .font(.appMicro)
                    .foregroundColor(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    Task { await loadStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.appMicro)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func runtimeCard(_ info: RAGRuntimeInfo) -> some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Runtime", bundle: .module), spacing: 8) {
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
                        label: LumiPluginLocalization.string("Last Indexed", bundle: .module),
                        value: relativeDate(status.lastIndexedAt)
                    )
                    GlassKeyValueRow(
                        label: LumiPluginLocalization.string("File Count", bundle: .module),
                        value: "\(status.fileCount)"
                    )
                    GlassKeyValueRow(
                        label: LumiPluginLocalization.string("Chunk Count", bundle: .module),
                        value: "\(status.chunkCount)"
                    )
                    AppSettingsRow {
                        HStack {
                            Text(LumiPluginLocalization.string("Status", bundle: .module))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            GlassBadge(
                                text: LocalizedStringKey(
                                    status.isStale
                                        ? LumiPluginLocalization.string("Outdated", bundle: .module)
                                        : LumiPluginLocalization.string("Up to Date", bundle: .module)
                                ),
                                style: status.isStale ? .warning : .success
                            )
                        }
                    }
                } else if isLoading {
                    Text(LumiPluginLocalization.string("Loading…", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text(LumiPluginLocalization.string("Not indexed yet", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }


                if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                    ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                    Text(String(format: LumiPluginLocalization.string("Progress: %lld/%lld", bundle: .module), progress.scannedFiles, progress.totalFiles))
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
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
            let service = RAGPlugin.getService()
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
        let projects = lumiCore.projectComponent.projects.map { RAGTrackedProject(name: $0.name, path: $0.path) } ?? []
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
