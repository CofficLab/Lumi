import LumiUI
import SuperLogKit
import RAGKit
import os
import SwiftUI

/// RAG 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的 RAG 索引状态
/// 支持悬停弹出详细信息
public struct RAGStatusBarView: View, SuperLog {
    public nonisolated static let emoji = "🦞"
    public nonisolated static let verbose: Bool = true
    // MARK: - 属性
    @State private var indexStatus: RAGIndexStatus?
    @State private var isIndexing = false
    @State private var progressEvent: RAGIndexProgressEvent?
    @State private var errorMessage: String?
    @State private var isNotInitialized = false
    @State private var lastUpdateAttempt: Date = .distantPast

    public init() {}

    // MARK: - 计算属性

    private var hasError: Bool {
        (errorMessage != nil && indexStatus == nil && !isIndexing) || isNotInitialized
    }

    // MARK: - 正文

    public var body: some View {
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
        .onChange(of: RAGPluginRuntime.currentProjectPath) { _, _ in
            // 项目切换时重新加载
            Task {
                await resetAndReload()
            }
        }
    }

    // MARK: - 状态栏内容

    @ViewBuilder
    private var statusBarContent: some View {
        statusIcon
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    // MARK: - 视图构建

    @ViewBuilder
    private var statusIcon: some View {
        if isIndexing {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.appMicroEmphasized)
                
        } else if let status = indexStatus {
            if status.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.appMicroEmphasized)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.appMicroEmphasized)
            }
        } else if isNotInitialized {
            Image(systemName: "poweroff")
                .font(.appMicroEmphasized)
        } else if hasError {
            Image(systemName: "xmark.circle.fill")
                .font(.appMicroEmphasized)
        } else {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.appMicroEmphasized)
        }
    }

    // MARK: - 通知处理

    private func handleProgressNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let projectPath = userInfo["projectPath"] as? String,
              projectPath == RAGPluginRuntime.currentProjectPath else {
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
        let projectPath = RAGPluginRuntime.currentProjectPath

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
                if RAGPlugin.verbose {
                                    RAGPlugin.logger.info("\(Self.t)RAG status update throttled")
                }
            }
            return
        }
        lastUpdateAttempt = now

        // 如果正在索引，不更新状态（避免冲突）
        if isIndexing {
            if RAGPlugin.verbose {
                if RAGPlugin.verbose {
                                    RAGPlugin.logger.info("\(Self.t)RAG is indexing, skip status update")
                }
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
                        if RAGPlugin.verbose {
                                                    RAGPlugin.logger.info(
                                                        "\(Self.t)RAG index status updated: \(status.projectPath), files: \(status.fileCount), chunks: \(status.chunkCount), stale: \(status.isStale)"
                                                    )
                        }
                    }
                }
            }
        } catch {
            // 检查是否是未初始化错误
            if error.localizedDescription.contains("RAG 服务未初始化") {
                isNotInitialized = true
                errorMessage = nil
                if Self.verbose {
                    if RAGPlugin.verbose {
                                            RAGPlugin.logger.info("\(Self.t)RAG service not initialized")
                    }
                }
                return
            }

            // 只在没有状态且不在索引中时才显示错误
            if indexStatus == nil && !isIndexing && !isNotInitialized {
                errorMessage = String(localized: "Failed to get status", table: "RAG")
                if RAGPlugin.verbose {
                                    RAGPlugin.logger.error("\(Self.t)Failed to get RAG index status: \(error.localizedDescription)")
                }
            } else {
                // 如果已经有状态或正在索引，清除错误（保留现有状态）
                errorMessage = nil
            }
        }
    }
}

// MARK: - RAG Status Detail View

/// RAG 状态详情视图（在 popover 中显示）
public struct RAGStatusDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let indexStatus: RAGIndexStatus?
    public let isIndexing: Bool
    public let progressEvent: RAGIndexProgressEvent?
    public let errorMessage: String?
    public let isNotInitialized: Bool

    public var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "RAG 索引状态", table: "RAG"),
            systemImage: "doc.text.magnifyingglass"
        ) {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)

                Text(String(localized: "正在索引...", table: "RAG"))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.primary)
            }

            if let event = progressEvent {
                VStack(alignment: .leading, spacing: 8) {
                    RAGProgressRow(label: String(localized: "已扫描", table: "RAG"), value: "\(event.scannedFiles) / \(event.totalFiles) \(String(localized: "文件", table: "RAG"))")
                    RAGProgressRow(label: String(localized: "已索引", table: "RAG"), value: "\(event.indexedFiles) \(String(localized: "文件", table: "RAG"))")
                    RAGProgressRow(label: String(localized: "已跳过", table: "RAG"), value: "\(event.skippedFiles) \(String(localized: "文件", table: "RAG"))")
                    RAGProgressRow(label: String(localized: "文档块", table: "RAG"), value: "\(event.chunkCount) \(String(localized: "个", table: "RAG"))")

                    if !event.currentFilePath.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "当前文件", table: "RAG"))
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)

                            Text((event.currentFilePath as NSString).lastPathComponent)
                                .font(.appMicro)
                                .foregroundColor(theme.textTertiary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indexStatusView(_ status: RAGIndexStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RAGInfoRow(label: String(localized: "文件数量", table: "RAG"), value: "\(status.fileCount)")
            RAGInfoRow(label: String(localized: "文档块数量", table: "RAG"), value: "\(status.chunkCount)")
            RAGInfoRow(label: String(localized: "最后索引", table: "RAG"), value: formatIndexTime(status.lastIndexedAt))
            RAGInfoRow(label: String(localized: "嵌入模型", table: "RAG"), value: status.embeddingModel)
            RAGInfoRow(label: String(localized: "向量维度", table: "RAG"), value: "\(status.embeddingDimension)")

            if status.isStale {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)

                    Text(String(localized: "索引已过期，建议重新索引", table: "RAG"))
                        .font(.appCaption)
                        .foregroundColor(theme.warning)
                }
            }
        }
    }

    @ViewBuilder
    private var notInitializedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "poweroff")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(theme.textTertiary)

            Text(String(localized: "RAG 索引未初始化", table: "RAG"))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)

            Text(String(localized: "RAG 服务将在插件启用时自动初始化", table: "RAG"))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(theme.error)

            Text(String(localized: "获取索引状态失败", table: "RAG"))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.error)

            if let error = errorMessage {
                Text(error)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)

            Text(String(localized: "正在检查索引状态...", table: "RAG"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
public struct RAGProgressRow: View {
    public let label: String
    public let value: String

    public var body: some View {
        StatusBarPopoverInfoRow(label: label, value: value)
    }
}

/// RAG 信息行
public struct RAGInfoRow: View {
    public let label: String
    public let value: String

    public var body: some View {
        StatusBarPopoverInfoRow(label: label, value: value)
    }
}
