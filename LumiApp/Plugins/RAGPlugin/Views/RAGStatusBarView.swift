import SwiftUI
import OSLog

/// RAG 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的 RAG 索引状态
struct RAGStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var indexStatus: RAGIndexStatus?
    @State private var isIndexing = false
    @State private var progressEvent: RAGIndexProgressEvent?
    @State private var errorMessage: String?
    @State private var lastUpdateAttempt: Date = .distantPast

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "RAG.StatusBar")

    var body: some View {
        HStack(spacing: 8) {
            // 状态图标
            statusIcon

            // 状态文本
            if let status = indexStatus {
                statusText(for: status)
            } else if isIndexing {
                indexingText
            } else if projectVM.currentProjectPath.isEmpty {
                noProjectText
            } else if hasError {
                errorText
            } else {
                loadingText
            }
        }
        .task {
            await updateStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ragIndexProgressDidChange)) { notification in
            handleProgressNotification(notification)
        }
        .onChange(of: projectVM.currentProjectPath) { oldValue, newValue in
            // 项目切换时重新加载状态
            Task {
                await resetAndReload()
            }
        }
    }

    // MARK: - Computed Properties

    private var hasError: Bool {
        errorMessage != nil && indexStatus == nil && !isIndexing
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        if isIndexing {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10))
                .foregroundColor(.blue)
                .symbolEffect(.rotate, options: .repeating)
        } else if let status = indexStatus {
            if status.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        } else if hasError {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.red)
        } else {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Status Text

    @ViewBuilder
    private func statusText(for status: RAGIndexStatus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("RAG")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Text("·")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text(formatIndexTime(status.lastIndexedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                Text("\(status.fileCount) 文件")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("·")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text("\(status.chunkCount) 片段")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var indexingText: some View {
        if let event = progressEvent {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("RAG 索引中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)

                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    Text("\(event.scannedFiles)/\(event.totalFiles)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 4) {
                    Text("\(event.indexedFiles) 已索引")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("·")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    Text("\(event.chunkCount) 片段")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.7))
                            .frame(
                                width: geometry.size.width * CGFloat(event.scannedFiles) / CGFloat(max(event.totalFiles, 1)),
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            }
        } else {
            Text("RAG 索引中...")
                .font(.system(size: 11))
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 10))
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var noProjectText: some View {
        Text("未选择项目")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var loadingText: some View {
        Text("检查索引状态...")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }

    // MARK: - Helper Methods

    private func formatIndexTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days)天前"
        }
    }

    // MARK: - State Management

    private func resetAndReload() async {
        // 重置所有状态
        indexStatus = nil
        isIndexing = false
        progressEvent = nil
        errorMessage = nil
        lastUpdateAttempt = .distantPast

        // 重新加载
        await updateStatus()
    }

    private func updateStatus() async {
        let projectPath = projectVM.currentProjectPath

        guard !projectPath.isEmpty else {
            indexStatus = nil
            isIndexing = false
            errorMessage = nil
            return
        }

        // 避免频繁更新（节流：最小间隔 1 秒）
        let now = Date()
        guard now.timeIntervalSince(lastUpdateAttempt) > 1.0 else {
            if RAGPlugin.verbose {
                logger.info("RAG 状态更新被节流")
            }
            return
        }
        lastUpdateAttempt = now

        // 如果正在索引，不更新状态（避免冲突）
        if isIndexing {
            if RAGPlugin.verbose {
                logger.info("RAG 正在索引中，跳过状态更新")
            }
            return
        }

        do {
            let ragService = await RAGPlugin.getService()
            let status = try await ragService.getIndexStatus(projectPath: projectPath)

            // 只在非索引状态下才更新状态
            if !isIndexing {
                indexStatus = status
                errorMessage = nil

                if RAGPlugin.verbose, let status = indexStatus {
                    logger.info(
                        "RAG 索引状态已更新: \(status.projectPath), 文件数: \(status.fileCount), 片段数: \(status.chunkCount), 是否过期: \(status.isStale)"
                    )
                }
            }
        } catch {
            // 只在没有状态且不在索引中时才显示错误
            if indexStatus == nil && !isIndexing {
                errorMessage = "获取状态失败"
                logger.error("获取 RAG 索引状态失败: \(error)")
            } else {
                // 如果已经有状态或正在索引，清除错误（保留现有状态）
                errorMessage = nil
            }
        }
    }

    private func handleProgressNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let projectPath = userInfo["projectPath"] as? String,
              projectPath == projectVM.currentProjectPath else {
            return
        }

        guard let scannedFiles = userInfo["scannedFiles"] as? Int,
              let totalFiles = userInfo["totalFiles"] as? Int,
              let indexedFiles = userInfo["indexedFiles"] as? Int,
              let skippedFiles = userInfo["skippedFiles"] as? Int,
              let chunkCount = userInfo["chunkCount"] as? Int,
              let currentFilePath = userInfo["currentFilePath"] as? String,
              let isFinished = userInfo["isFinished"] as? Bool else {
            return
        }

        // 索引开始或进行中
        isIndexing = !isFinished
        errorMessage = nil // 清除错误信息

        progressEvent = RAGIndexProgressEvent(
            projectPath: projectPath,
            scannedFiles: scannedFiles,
            totalFiles: totalFiles,
            indexedFiles: indexedFiles,
            skippedFiles: skippedFiles,
            chunkCount: chunkCount,
            currentFilePath: currentFilePath,
            isFinished: isFinished
        )

        if RAGPlugin.verbose {
            logger.info(
                "RAG 索引进度: \(scannedFiles)/\(totalFiles), 已索引: \(indexedFiles), 片段: \(chunkCount), 完成: \(isFinished)"
            )
        }

        if isFinished {
            // 索引完成后刷新状态
            Task {
                // 延迟一下，确保数据库写入完成
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

                // 重置索引状态
                isIndexing = false

                // 刷新索引状态
                await updateStatus()

                // 再延迟后重置进度事件
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
                progressEvent = nil
            }
        }
    }
}

// MARK: - Preview

#Preview("未选择项目") {
    let projectVM = ProjectVM(
        contextService: ContextService(),
        llmService: LLMService()
    )

    RAGStatusBarView()
        .environmentObject(projectVM)
        .frame(height: 50)
        .padding()
}
