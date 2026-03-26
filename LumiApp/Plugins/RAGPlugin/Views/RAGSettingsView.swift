import SwiftUI

@MainActor
struct RAGSettingsView: View {
    @EnvironmentObject private var projectVM: ProjectVM

    @State private var status: RAGIndexStatus?
    @State private var runtimeInfo: RAGRuntimeInfo?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RAG 索引状态")
                .font(.headline)

            if let projectPath = selectedProjectPath {
                Text(projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if let status {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        GridRow {
                            Text("最近索引")
                                .foregroundStyle(.secondary)
                            Text(relativeDate(status.lastIndexedAt))
                        }
                        GridRow {
                            Text("文件数")
                                .foregroundStyle(.secondary)
                            Text("\(status.fileCount)")
                        }
                        GridRow {
                            Text("片段数")
                                .foregroundStyle(.secondary)
                            Text("\(status.chunkCount)")
                        }
                        GridRow {
                            Text("Embedding")
                                .foregroundStyle(.secondary)
                            Text("\(status.embeddingModel) (\(status.embeddingDimension))")
                        }
                        GridRow {
                            Text("状态")
                                .foregroundStyle(.secondary)
                            Text(status.isStale ? "已过期" : "最新")
                                .foregroundStyle(status.isStale ? .orange : .green)
                        }
                        if let runtimeInfo {
                            GridRow {
                                Text("向量后端")
                                    .foregroundStyle(.secondary)
                                Text(runtimeInfo.vectorBackend.rawValue)
                            }
                            if let path = runtimeInfo.sqliteVecPath {
                                GridRow {
                                    Text("sqlite-vec")
                                        .foregroundStyle(.secondary)
                                    Text(path)
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                }
                            }
                            if let note = runtimeInfo.note {
                                GridRow {
                                    Text("说明")
                                        .foregroundStyle(.secondary)
                                    Text(note)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView("读取索引状态…")
                } else {
                    Text("当前项目尚未建立索引。")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button("刷新状态") {
                        Task { await loadStatus() }
                    }
                    .disabled(isLoading)

                    Button("立即重建索引") {
                        Task { await rebuildIndex() }
                    }
                    .disabled(isLoading)
                }

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("请先选择项目，RAG 才能建立与展示索引。")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .task(id: selectedProjectPath) {
            await loadStatus()
        }
    }

    private var selectedProjectPath: String? {
        let path = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func loadStatus() async {
        guard let selectedProjectPath else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = RootViewContainer.shared.ragService
            try await service.initialize()
            status = try await service.getIndexStatus(projectPath: selectedProjectPath)
            runtimeInfo = try await service.getRuntimeInfo()
            if status == nil {
                message = "尚未索引，首次提问触发 RAG 时会自动建立索引。"
            } else {
                message = nil
            }
        } catch {
            message = "读取索引状态失败：\(error.localizedDescription)"
        }
    }

    private func rebuildIndex() async {
        guard let selectedProjectPath else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let service = RootViewContainer.shared.ragService
            try await service.initialize()
            try await service.ensureIndexed(projectPath: selectedProjectPath, force: true)
            status = try await service.getIndexStatus(projectPath: selectedProjectPath)
            runtimeInfo = try await service.getRuntimeInfo()
            message = "索引更新完成。"
        } catch {
            message = "重建索引失败：\(error.localizedDescription)"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
