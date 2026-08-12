import AppKit
import LumiKernel
import LumiUI
import SuperLogKit
import os
import SwiftUI

/// 嵌入"项目"设置页项目详情的"代码索引"区块。
///
/// 由 ProjectRAGPlugin 通过 `settingsSections(kernel:)` 贡献到 ProjectsPlugin 的
/// "项目" tab。本视图自给自足：通过 `ProjectRAGPlugin.getService()` 获取该项目的
/// 索引状态与运行时信息，并在底部提供全局索引控制（暂停/恢复、打开数据目录）。
@MainActor
struct RAGProjectDetailSectionView: View, SuperLog {
    nonisolated static let emoji = ProjectRAGPlugin.emoji
    nonisolated static let verbose = ProjectRAGPlugin.verbose
    nonisolated static let logger = ProjectRAGPlugin.logger

    private let projectPath: String
    private let kernel: LumiKernel

    @LumiTheme private var theme
    @State private var status: RAGIndexStatus?
    @State private var progress: RAGIndexProgressEvent?
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var isLoading = false
    @State private var isIndexingPaused = false

    init(projectPath: String, kernel: LumiKernel) {
        self.projectPath = projectPath
        self.kernel = kernel
    }

    private var normalizedPath: String {
        RAGPathUtils.normalizeProjectPath(projectPath)
    }

    var body: some View {
        AppSettingSection(
            title: LumiPluginLocalization.string("Code Index", bundle: .module),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                statusRow
                Divider().padding(.vertical, 8)

                if let status {
                    detailRow(
                        title: LumiPluginLocalization.string("Last Indexed", bundle: .module),
                        icon: "clock",
                        value: relativeDate(status.lastIndexedAt)
                    )
                    Divider().padding(.vertical, 8)

                    detailRow(
                        title: LumiPluginLocalization.string("Files", bundle: .module),
                        icon: "doc",
                        value: "\(status.fileCount)"
                    )
                    Divider().padding(.vertical, 8)

                    detailRow(
                        title: LumiPluginLocalization.string("Chunks", bundle: .module),
                        icon: "square.stack.3d.up",
                        value: "\(status.chunkCount)"
                    )
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: LumiPluginLocalization.string("Embedding", bundle: .module),
                        description: "dim \(status.embeddingDimension)",
                        icon: "brain.head.profile"
                    ) {
                        Text(status.embeddingModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    detailRow(
                        title: LumiPluginLocalization.string("Status", bundle: .module),
                        icon: "ellipsis.circle",
                        value: LumiPluginLocalization.string("Loading…", bundle: .module)
                    )
                } else {
                    detailRow(
                        title: LumiPluginLocalization.string("Status", bundle: .module),
                        icon: "circle.dashed",
                        value: LumiPluginLocalization.string("Not indexed yet", bundle: .module)
                    )
                }

                if let progress, progress.totalFiles > 0, !progress.isFinished {
                    Divider().padding(.vertical, 8)
                    AppSettingRow(
                        title: LumiPluginLocalization.string("Progress", bundle: .module),
                        icon: "progress.indicator"
                    ) {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                                .frame(maxWidth: 160)
                            Text(
                                String(
                                    format: LumiPluginLocalization.string("Progress: %lld/%lld", bundle: .module),
                                    locale: .current,
                                    progress.scannedFiles,
                                    progress.totalFiles
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }
                }

                Divider().padding(.vertical, 8)
                globalControls
            }
        }
        .task(id: projectPath) {
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            // 进度事件携带的 projectPath 已标准化；与本项目标准化后比较。
            guard RAGPathUtils.normalizeProjectPath(event.projectPath) == normalizedPath else { return }
            progress = event
            if event.isFinished {
                Task { await loadStatus() }
            }
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private var statusRow: some View {
        if let progress, !progress.isFinished {
            AppSettingRow(
                title: LumiPluginLocalization.string("Status", bundle: .module),
                icon: "arrow.triangle.2.circlepath"
            ) {
                statusPill(text: LumiPluginLocalization.string("Indexing", bundle: .module), color: .blue, spinning: true)
            }
        } else if let status {
            if status.isStale {
                AppSettingRow(
                    title: LumiPluginLocalization.string("Status", bundle: .module),
                    icon: "exclamationmark.triangle.fill"
                ) {
                    statusPill(text: LumiPluginLocalization.string("Outdated", bundle: .module), color: .orange, spinning: false)
                }
            } else {
                AppSettingRow(
                    title: LumiPluginLocalization.string("Status", bundle: .module),
                    icon: "checkmark.circle.fill"
                ) {
                    statusPill(text: LumiPluginLocalization.string("Up to Date", bundle: .module), color: .green, spinning: false)
                }
            }
        } else if isLoading {
            AppSettingRow(
                title: LumiPluginLocalization.string("Status", bundle: .module),
                icon: "ellipsis.circle"
            ) {
                statusPill(text: LumiPluginLocalization.string("Loading…", bundle: .module), color: .secondary, spinning: false)
            }
        } else {
            AppSettingRow(
                title: LumiPluginLocalization.string("Status", bundle: .module),
                icon: "circle.dashed"
            ) {
                statusPill(text: LumiPluginLocalization.string("Not Indexed", bundle: .module), color: .secondary, spinning: false)
            }
        }
    }

    // MARK: - Global Controls

    @ViewBuilder
    private var globalControls: some View {
        if let runtimeInfo {
            detailRow(
                title: LumiPluginLocalization.string("Vector Backend", bundle: .module),
                icon: "cpu",
                value: runtimeInfo.vectorBackend.rawValue
            )
            Divider().padding(.vertical, 8)
        }

        AppSettingRow(
            title: LumiPluginLocalization.string("Indexing", bundle: .module),
            icon: isIndexingPaused ? "play.fill" : "pause.fill"
        ) {
            AppButton(
                isIndexingPaused
                    ? LumiPluginLocalization.string("Resume Indexing", bundle: .module)
                    : LumiPluginLocalization.string("Pause Indexing", bundle: .module),
                systemImage: isIndexingPaused ? "play.fill" : "pause.fill",
                size: .small
            ) {
                toggleIndexingPause()
            }
        }
        Divider().padding(.vertical, 8)

        AppSettingRow(
            title: LumiPluginLocalization.string("Data Directory", bundle: .module),
            icon: "folder"
        ) {
            AppButton(
                LumiPluginLocalization.string("Open", bundle: .module),
                systemImage: "arrow.up.right.square",
                size: .small
            ) {
                openDataDirectory()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailRow(title: String, icon: String, value: String) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusPill(text: String, color: Color, spinning: Bool) -> some View {
        HStack(spacing: 4) {
            if spinning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Data

    private func loadStatus() async {
        isLoading = true
        defer { isLoading = false }
        let service = ProjectRAGPlugin.getService()
        do {
            try await service.initialize()
            isIndexingPaused = await service.isIndexingPaused()
            runtimeInfo = try await service.getRuntimeInfo()
            status = try await service.getIndexStatus(projectPath: projectPath)
            if Self.verbose {
                Self.logger.info("\(Self.t)detail-section loaded project=\(projectPath) files=\(status?.fileCount ?? -1) paused=\(isIndexingPaused)")
            }
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)detail-section loadStatus failed project=\(projectPath) error=\(error.localizedDescription)")
            }
        }
    }

    private func toggleIndexingPause() {
        let shouldPause = !isIndexingPaused
        // 乐观更新：UI 立即反映，actor 在后台执行实际暂停/恢复。
        isIndexingPaused = shouldPause
        Task { @MainActor in
            await ProjectRAGOnReadyHook().setIndexingPaused(shouldPause, kernel: kernel)
            if shouldPause { progress = nil }
            await loadStatus()
        }
    }

    private func openDataDirectory() {
        let url = kernel.storage?.pluginDataDirectory(for: "RAG")
            ?? RAGPluginRuntime.databaseDirectoryProvider()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
