import MagicKit
import os
import SwiftUI

/// RAG 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的 RAG 索引状态
/// 支持悬停弹出详细信息
struct RAGStatusBarView: View, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let verbose: Bool = false
    // MARK: - 属性

    @EnvironmentObject private var projectVM: ProjectVM
    @State private var indexStatus: RAGIndexStatus?
    @State private var isIndexing = false
    @State private var progressEvent: RAGIndexProgressEvent?
    @State private var errorMessage: String?
    @State private var isNotInitialized = false
    @State private var lastUpdateAttempt: Date = .distantPast

    // MARK: - 计算属性

    private var hasError: Bool {
        (errorMessage != nil && indexStatus == nil && !isIndexing) || isNotInitialized
    }

    // MARK: - 正文

    var body: some View {
        StatusBarHoverContainer(
            detailView: RAGStatusDetailView(
                indexStatus: indexStatus,
                isIndexing: isIndexing,
                progressEvent: progressEvent,
                errorMessage: errorMessage,
                isNotInitialized: isNotInitialized
            ),
            popoverWidth: 420,
            id: "rag-status"
        ) {
            statusBarContent
        }
        .task {
            await updateStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ragIndexProgressDidChange)) { notification in
            handleProgressNotification(notification)
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            // 项目切换时重新加载
            Task {
                await resetAndReload()
            }
        }
    }

    // MARK: - 状态栏内容

    @ViewBuilder
    private var statusBarContent: some View {
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
            } else if isNotInitialized {
                notInitializedText
            } else if hasError {
                errorText
            } else {
                loadingText
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - 视图构建

    @ViewBuilder
    private var statusIcon: some View {
        // 状态图标保留颜色以区分状态
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
        } else if isNotInitialized {
            Image(systemName: "poweroff")
                .font(.system(size: 10))
                .foregroundColor(.gray)
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

    @ViewBuilder
    private func statusText(for status: RAGIndexStatus) -> some View {
        // 状态栏文本不设置颜色，由 StatusBar 统一控制为白色
        HStack(spacing: 4) {
            Text(String(localized: "RAG", table: "RAG"))
                .font(.system(size: 11, weight: .medium))

            Text("·")
                .font(.system(size: 9))
                .opacity(0.7)

            Text(formatIndexTime(status.lastIndexedAt))
                .font(.system(size: 10))
                .opacity(0.7)

            Text("·")
                .font(.system(size: 9))
                .opacity(0.7)

            Text("^[\(status.fileCount) File](inflect: true)")
                .font(.system(size: 10))

            Text("·")
                .font(.system(size: 9))
                .opacity(0.7)

            Text("^[\(status.chunkCount) Chunk](inflect: true)")
                .font(.system(size: 10))
        }
    }

    @ViewBuilder
    private var indexingText: some View {
        if let event = progressEvent {
            HStack(spacing: 4) {
                Text(String(localized: "Indexing...", table: "RAG"))
                    .font(.system(size: 11, weight: .medium))

                Text("·")
                    .font(.system(size: 9))
                    .opacity(0.7)

                Text("\(event.scannedFiles)/\(event.totalFiles)")
                    .font(.system(size: 10))
                    .opacity(0.7)
            }
        } else {
            Text(String(localized: "Indexing...", table: "RAG"))
                .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private var notInitializedText: some View {
        Text(String(localized: "Not initialized", table: "RAG"))
            .font(.system(size: 10))
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = errorMessage {
            Text(error)
                .font(.system(size: 10))
        }
    }

    @ViewBuilder
    private var noProjectText: some View {
        Text(String(localized: "No project selected", table: "RAG"))
            .font(.system(size: 10))
    }

    @ViewBuilder
    private var loadingText: some View {
        Text(String(localized: "Checking index status...", table: "RAG"))
            .font(.system(size: 10))
    }

    // MARK: - 通知处理

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
        errorMessage = nil
        isNotInitialized = false

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

        if isFinished {
            // 索引完成后刷新状态
            Task {
                // 延迟一下，确保数据库写入完成
                try? await Task.sleep(nanoseconds: 500000000) // 0.5 秒

                // 重置索引状态
                isIndexing = false

                // 刷新索引状态
                await updateStatus()

                // 再延迟后重置进度事件
                try? await Task.sleep(nanoseconds: 1500000000) // 1.5 秒
                progressEvent = nil
            }
        }
    }

    // MARK: - 私有方法

    private func formatIndexTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return String(localized: "Just now", table: "RAG")
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(localized: "^[\(minutes) minute](inflect: true) ago", table: "RAG")
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(localized: "^[\(hours) hour](inflect: true) ago", table: "RAG")
        } else {
            let days = Int(interval / 86400)
            return String(localized: "^[\(days) day](inflect: true) ago", table: "RAG")
        }
    }

    private func resetAndReload() async {
        // 重置所有状态
        indexStatus = nil
        isIndexing = false
        progressEvent = nil
        errorMessage = nil
        isNotInitialized = false
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
            isNotInitialized = false
            return
        }

        // 避免频繁更新（节流：最小间隔 1 秒）
        let now = Date()
        guard now.timeIntervalSince(lastUpdateAttempt) > 1.0 else {
            if RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)RAG status update throttled")
            }
            return
        }
        lastUpdateAttempt = now

        // 如果正在索引，不更新状态（避免冲突）
        if isIndexing {
            if RAGPlugin.verbose {
                RAGPlugin.logger.info("\(Self.t)RAG is indexing, skip status update")
            }
            return
        }

        do {
            let ragService = RAGPlugin.getService()
            // 服务已在 onEnable 时初始化
            let status = try await ragService.getIndexStatus(projectPath: projectPath)

            // 只在非索引状态下才更新状态
            if !isIndexing {
                indexStatus = status
                errorMessage = nil
                isNotInitialized = false

                if RAGPlugin.verbose, let status = indexStatus {
                    if Self.verbose {
                        RAGPlugin.logger.info(
                            "\(Self.t)RAG index status updated: \(status.projectPath), files: \(status.fileCount), chunks: \(status.chunkCount), stale: \(status.isStale)"
                        )
                    }
                }
            }
        } catch {
            // 检查是否是未初始化错误
            if error.localizedDescription.contains("RAG 服务未初始化") {
                isNotInitialized = true
                errorMessage = nil
                if Self.verbose {
                    RAGPlugin.logger.info("\(Self.t)RAG service not initialized")
                }
                return
            }

            // 只在没有状态且不在索引中时才显示错误
            if indexStatus == nil && !isIndexing && !isNotInitialized {
                errorMessage = String(localized: "Failed to get status", table: "RAG")
                RAGPlugin.logger.error("\(Self.t)Failed to get RAG index status: \(error.localizedDescription)")
            } else {
                // 如果已经有状态或正在索引，清除错误（保留现有状态）
                errorMessage = nil
            }
        }
    }
}

// MARK: - RAG Status Detail View

/// RAG 状态详情视图（在 popover 中显示）
struct RAGStatusDetailView: View {
    let indexStatus: RAGIndexStatus?
    let isIndexing: Bool
    let progressEvent: RAGIndexProgressEvent?
    let errorMessage: String?
    let isNotInitialized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("RAG 索引状态")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            if isIndexing {
                indexingView()
            } else if let status = indexStatus {
                indexStatusView(status)
            } else if isNotInitialized {
                notInitializedView
            } else if errorMessage != nil {
                errorView
            } else {
                loadingView
            }
        }
    }

    @ViewBuilder
    private func indexingView() -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)

                Text("正在索引...")
                    .font(.system(size: 13))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
            }

            if let event = progressEvent {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    RAGProgressRow(label: "已扫描", value: "\(event.scannedFiles) / \(event.totalFiles) 文件")
                    RAGProgressRow(label: "已索引", value: "\(event.indexedFiles) 文件")
                    RAGProgressRow(label: "已跳过", value: "\(event.skippedFiles) 文件")
                    RAGProgressRow(label: "文档块", value: "\(event.chunkCount) 个")

                    if !event.currentFilePath.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前文件")
                                .font(.system(size: 11))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                            Text((event.currentFilePath as NSString).lastPathComponent)
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indexStatusView(_ status: RAGIndexStatus) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            RAGInfoRow(label: "文件数量", value: "\(status.fileCount)")
            RAGInfoRow(label: "文档块数量", value: "\(status.chunkCount)")
            RAGInfoRow(label: "最后索引", value: formatIndexTime(status.lastIndexedAt))
            RAGInfoRow(label: "嵌入模型", value: status.embeddingModel)
            RAGInfoRow(label: "向量维度", value: "\(status.embeddingDimension)")

            if status.isStale {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.warning)

                    Text("索引已过期，建议重新索引")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.warning)
                }
            }
        }
    }

    @ViewBuilder
    private var notInitializedView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "poweroff")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("RAG 索引未初始化")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text("RAG 服务将在插件启用时自动初始化")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.error)

            Text("获取索引状态失败")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.error)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)

            Text("正在检查索引状态...")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    private func formatIndexTime(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) 分钟前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) 小时前"
        } else {
            let days = Int(interval / 86400)
            return "\(days) 天前"
        }
    }
}

/// RAG 进度信息行
struct RAGProgressRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
    }
}

/// RAG 信息行
struct RAGInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
    }
}
