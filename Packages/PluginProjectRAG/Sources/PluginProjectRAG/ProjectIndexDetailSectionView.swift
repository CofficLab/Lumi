import LumiUI
import ProjectRAGPlugin
import SwiftUI

/// The project-scoped index section shown inside Settings > Projects.
@MainActor
public struct ProjectIndexDetailSectionView: View {
    private let projectPath: String
    private let service: RAGService

    @LumiTheme private var theme
    @State private var status: RAGIndexStatus?
    @State private var progress: RAGIndexProgressEvent?
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var paused = false
    @State private var isLoading = false
    @State private var isRebuilding = false

    public init(projectPath: String, service: RAGService) {
        self.projectPath = projectPath
        self.service = service
    }

    public var body: some View {
        AppSettingsSection(title: LumiPluginLocalization.string("Code Index", bundle: .module)) {
            VStack(spacing: 0) {
                statusRow
                if let status {
                    Divider().padding(.vertical, 8)
                    detailRow("Last Indexed", icon: "clock", value: relativeDate(status.lastIndexedAt))
                    Divider().padding(.vertical, 8)
                    detailRow("Files", icon: "doc", value: "\(status.fileCount)")
                    Divider().padding(.vertical, 8)
                    detailRow("Chunks", icon: "square.stack.3d.up", value: "\(status.chunkCount)")
                    Divider().padding(.vertical, 8)
                    detailRow("Embedding", icon: "brain.head.profile", value: "\(status.embeddingModel) (\(status.embeddingDimension) dim)")
                }
                if let progress, progress.totalFiles > 0, !progress.isFinished {
                    Divider().padding(.vertical, 8)
                    AppSettingRow(title: text("Progress"), icon: "progress.indicator") {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                                .frame(maxWidth: 140)
                            Text("\(progress.scannedFiles)/\(progress.totalFiles)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider().padding(.vertical, 8)
                AppSettingRow(title: text("Indexing"), icon: paused ? "play.fill" : "pause.fill") {
                    AppButton(
                        paused ? text("Resume Indexing") : text("Pause Indexing"),
                        systemImage: paused ? "play.fill" : "pause.fill",
                        size: .small
                    ) {
                        Task {
                            paused.toggle()
                            await service.setIndexingPaused(paused)
                            await loadStatus()
                        }
                    }
                }
                Divider().padding(.vertical, 8)
                AppSettingRow(title: text("Rebuild Index"), icon: "arrow.clockwise") {
                    AppButton(text("Rebuild"), systemImage: "arrow.clockwise", size: .small) {
                        Task {
                            isRebuilding = true
                            await service.ensureIndexedBackground(projectPath: projectPath, force: true)
                            isRebuilding = false
                            await loadStatus()
                        }
                    }
                    .disabled(isRebuilding || paused)
                }
                if let runtimeInfo {
                    Divider().padding(.vertical, 8)
                    detailRow("Vector Backend", icon: "cpu", value: runtimeInfo.vectorBackend.rawValue)
                }
            }
        }
        .task(id: projectPath) { await loadStatus() }
        .onRAGIndexProgressDidChange { event in
            guard RAGPathUtils.normalizeProjectPath(event.projectPath) == RAGPathUtils.normalizeProjectPath(projectPath) else { return }
            progress = event
            if event.isFinished { Task { await loadStatus() } }
        }
    }

    @ViewBuilder private var statusRow: some View {
        AppSettingRow(title: text("Status"), icon: statusIcon) {
            HStack(spacing: 5) {
                if isLoading || (progress != nil && progress?.isFinished == false) { ProgressView().controlSize(.mini) }
                Text(statusText).font(.caption).foregroundStyle(statusColor)
            }
        }
    }

    private var statusText: String {
        if progress?.isFinished == false { return text("Indexing") }
        if isLoading { return text("Loading…") }
        guard let status else { return text("Not Indexed") }
        return status.isStale ? text("Outdated") : text("Up to Date")
    }

    private var statusIcon: String {
        if progress?.isFinished == false { return "arrow.triangle.2.circlepath" }
        if status?.isStale == true { return "exclamationmark.triangle.fill" }
        return status == nil ? "circle.dashed" : "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if progress?.isFinished == false { return .blue }
        if status?.isStale == true { return .orange }
        return status == nil ? theme.textSecondary : .green
    }

    private func detailRow(_ key: String, icon: String, value: String) -> some View {
        AppSettingRow(title: text(key), icon: icon) {
            Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
    }

    private func text(_ key: String) -> String { LumiPluginLocalization.string(key, bundle: .module) }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if !service.isInitialized { try await service.initialize() }
            paused = await service.isIndexingPaused()
            runtimeInfo = try await service.getRuntimeInfo()
            status = try await service.getIndexStatus(projectPath: projectPath)
        } catch {
            status = nil
        }
    }
}
