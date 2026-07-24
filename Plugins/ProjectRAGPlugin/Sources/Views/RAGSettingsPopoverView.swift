import LumiUI
import SwiftUI
import LumiKernel

@MainActor
struct RAGSettingsPopoverView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing
    @State private var statusesByPath: [String: RAGIndexStatus] = [:]
    @State private var progressByPath: [String: RAGIndexProgressEvent] = [:]
    /// 向量后端运行时信息：sqlite-vec 不可用时为 nil 或 .swiftCosine，需要提示用户
    /// 语义检索性能会下降（回退到内存逐个余弦计算）。
    @State private var runtimeInfo: RAGRuntimeInfo?
    /// 状态加载失败时的错误提示
    @State private var loadError: String?

    init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("RAG Index Status", bundle: .module),
            systemImage: "doc.text.magnifyingglass"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if isVectorBackendDegraded {
                    vectorBackendWarning
                }
                if let loadError {
                    loadErrorBanner(loadError)
                }
                if trackedProjects.isEmpty {
                    Text(LumiPluginLocalization.string("No Projects", bundle: .module))
                        .foregroundColor(theme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(trackedProjects) { project in
                            projectRow(project)
                        }
                    }
                }
            }
        }
        .task(id: trackedProjectsKey) {
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            progressByPath[event.projectPath] = event
            if event.isFinished {
                Task { await loadStatus() }
            }
        }
    }

    /// sqlite-vec 扩展加载失败（回退到 swiftCosine）时提示用户语义检索会变慢。
    private var isVectorBackendDegraded: Bool {
        runtimeInfo?.vectorBackend != .sqliteVec
    }

    @ViewBuilder
    private var vectorBackendWarning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(LumiPluginLocalization.string("Vector acceleration unavailable", bundle: .module))
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.warning)
                Text(LumiPluginLocalization.string("sqlite-vec extension did not load; semantic search falls back to slower in-memory scoring.", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.warning.opacity(0.12))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func loadErrorBanner(_ message: String) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.error.opacity(0.12))
        .cornerRadius(8)
    }

    private var trackedProjectsKey: String {
        trackedProjects.map(\.path).joined(separator: "|")
    }

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(_ project: RAGTrackedProjectPopover) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)
            Text(project.path)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let status = statusesByPath[project.path] {
                HStack(spacing: 10) {
                    Label("\(status.fileCount)", systemImage: "doc")
                    Label("\(status.chunkCount)", systemImage: "square.stack.3d.up.fill")
                    Label(
                        status.isStale
                            ? LumiPluginLocalization.string("Outdated", bundle: .module)
                            : LumiPluginLocalization.string("Up to Date", bundle: .module),
                        systemImage: status.isStale ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundColor(status.isStale ? theme.warning : theme.success)
                }
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
            } else {
                Text(LumiPluginLocalization.string("Not indexed yet", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            if let progress = progressByPath[project.path], progress.totalFiles > 0, !progress.isFinished {
                ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.elevatedSurface)
        .cornerRadius(8)
    }

    // MARK: - Private

    private var trackedProjects: [RAGTrackedProjectPopover] {
        let recent = lumiCore.projectComponent.projects.map { RAGTrackedProjectPopover(name: $0.name, path: $0.path) } ?? []
        let currentPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let current: [RAGTrackedProjectPopover]
        if currentPath.isEmpty {
            current = []
        } else {
            let name = RAGPluginRuntime.currentProjectName.isEmpty
                ? URL(fileURLWithPath: currentPath).lastPathComponent
                : RAGPluginRuntime.currentProjectName
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
            // 同步拉取向量后端运行时信息，用于判定是否需要展示降级提示
            runtimeInfo = try await service.getRuntimeInfo()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct RAGTrackedProjectPopover: Identifiable, Equatable {
    var id: String { path }
    let name: String
    let path: String
}
