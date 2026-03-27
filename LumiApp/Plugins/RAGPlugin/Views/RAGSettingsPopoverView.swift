import SwiftUI
import os
import MagicKit

/// RAG 状态栏弹出的设置面板
///
/// 提供索引状态查看、刷新、重建等操作
@MainActor
struct RAGSettingsPopoverView: View, SuperLog {
    nonisolated static var emoji: String { "🦞" }
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject private var projectVM: ProjectVM
    @Environment(\.dismiss) private var dismiss

    @State private var status: RAGIndexStatus?
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var isLoading = false
    @State private var message: String?
    @State private var indexProgress: RAGIndexProgressEvent?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Label("RAG 索引设置", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let projectPath = selectedProjectPath {
                        // 项目路径
                        VStack(alignment: .leading, spacing: 6) {
                            Text("项目路径")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)

                            Text(projectPath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                                .textSelection(.enabled)
                        }

                        // 索引状态
                        if let status {
                            VStack(alignment: .leading, spacing: 10) {
                                statusSection(for: status)

                                if let runtimeInfo {
                                    runtimeSection(for: runtimeInfo)
                                }
                            }
                        } else if isLoading {
                            ProgressView("读取索引状态…")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            Text("当前项目尚未建立索引。")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }

                        // 操作按钮
                        actionButtons

                        // 进度显示
                        if let progress = indexProgress, progress.totalFiles > 0, !progress.isFinished {
                            progressSection(for: progress)
                        }

                        // 消息提示
                        if let message {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    } else {
                        // 未选择项目
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)

                            Text("请先选择项目")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("RAG 需要选择项目后才能建立和展示索引")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                }
                .padding(16)
            }
        }
        .task(id: selectedProjectPath) {
            await loadStatus()
        }
        .onRAGIndexProgressDidChange { event in
            guard event.projectPath == selectedProjectPath else { return }
            indexProgress = event
            if event.isFinished {
                message = "✓ 索引更新完成"
            } else {
                message = "正在重建索引：\(event.scannedFiles)/\(event.totalFiles)"
            }
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private func statusSection(for status: RAGIndexStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("索引状态")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                statusRow(label: "最近索引", value: relativeDate(status.lastIndexedAt))
                statusRow(label: "文件数", value: "\(status.fileCount)")
                statusRow(label: "片段数", value: "\(status.chunkCount)")
                statusRow(label: "Embedding", value: "\(status.embeddingModel) (\(status.embeddingDimension))")

                HStack {
                    Text("状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)

                    if status.isStale {
                        Label("已过期", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Label("最新", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func runtimeSection(for runtimeInfo: RAGRuntimeInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("运行时信息")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                statusRow(label: "向量后端", value: runtimeInfo.vectorBackend.rawValue)

                if let path = runtimeInfo.sqliteVecPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("sqlite-vec")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)

                        Text(path)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }

                if let note = runtimeInfo.note {
                    statusRow(label: "说明", value: note)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: {
                Task { await loadStatus() }
            }) {
                Label("刷新状态", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
            .controlSize(.regular)

            Button(action: {
                Task { await rebuildIndex() }
            }) {
                Label("重建索引", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
            .controlSize(.regular)
        }
    }

    @ViewBuilder
    private func progressSection(for progress: RAGIndexProgressEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("索引进度")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))

                HStack(spacing: 12) {
                    Label("\(progress.scannedFiles)/\(progress.totalFiles)", systemImage: "doc.text")
                        .font(.caption2)

                    Label("\(progress.indexedFiles) indexed", systemImage: "checkmark")
                        .font(.caption2)

                    Label("\(progress.skippedFiles) skipped", systemImage: "minus.circle")
                        .font(.caption2)

                    Spacer()

                    Label("\(progress.chunkCount)", systemImage: "square.stack.3d.up")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                if !progress.currentFilePath.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(progress.currentFilePath)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - 私有方法

    private var selectedProjectPath: String? {
        let path = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func loadStatus() async {
        guard let selectedProjectPath else { return }
        AppLogger.core.info("\(Self.t) 开始读取状态，project=\(selectedProjectPath)")
        isLoading = true
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            try await service.initialize()
            status = try await service.getIndexStatus(projectPath: selectedProjectPath)
            runtimeInfo = try await service.getRuntimeInfo()

            if let status {
                AppLogger.core.info(
                    "\(Self.t) 状态读取完成 fileCount=\(status.fileCount) chunkCount=\(status.chunkCount) embedding=\(status.embeddingModel)"
                )
            } else {
                AppLogger.core.info("\(Self.t) 状态读取完成：当前项目尚未索引")
            }

            if status == nil {
                message = "尚未索引，首次提问触发 RAG 时会自动建立索引"
            } else {
                message = nil
            }
        } catch {
            AppLogger.core.error("\(Self.t) 读取状态失败：\(error.localizedDescription)")
            message = "读取索引状态失败：\(error.localizedDescription)"
        }
    }

    private func rebuildIndex() async {
        guard let selectedProjectPath else { return }
        AppLogger.core.info("\(Self.t) 用户点击立即重建索引，project=\(selectedProjectPath)")
        isLoading = true
        message = "正在重建索引，稍后可看到进度"
        defer { isLoading = false }

        do {
            let service = RAGPlugin.getService()
            try await service.initialize()
            try await service.ensureIndexed(projectPath: selectedProjectPath, force: true)
            status = try await service.getIndexStatus(projectPath: selectedProjectPath)
            runtimeInfo = try await service.getRuntimeInfo()
            message = "✓ 索引更新完成"
            indexProgress = nil

            if let status {
                AppLogger.core.info(
                    "\(Self.t) 重建完成 fileCount=\(status.fileCount) chunkCount=\(status.chunkCount) embedding=\(status.embeddingModel)"
                )
            } else {
                AppLogger.core.info("\(Self.t) 重建完成，但状态为空")
            }
        } catch {
            AppLogger.core.error("\(Self.t) 重建失败：\(error.localizedDescription)")
            message = "重建索引失败：\(error.localizedDescription)"
            indexProgress = nil
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
