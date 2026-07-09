import LumiUI
import SuperLogKit
import os
import SwiftUI
import LumiCoreKit

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
            detailView: RAGSettingsPopoverView(),
            popoverWidth: 420,
            id: "rag-status"
        ) {
            statusBarContent
        }
        .task {
            await updateStatus()
        }
        .task(id: RAGPluginRuntime.currentProjectPath) {
            // 项目切换时重新加载（.onChange 无法观察计算属性）
            let path = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
            await resetAndReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ragIndexProgressDidChange)) { notification in
            handleProgressNotification(notification)
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
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)RAG status update throttled")
            }
            return
        }
        lastUpdateAttempt = now

        // 如果正在索引，不更新状态（避免冲突）
        if isIndexing {
            if Self.verbose {
                RAGPlugin.logger.info("\(Self.t)RAG is indexing, skip status update")
            }
            return
        }

        do {
            RAGPluginService.initializeIfNeeded()
            let ragService = RAGPlugin.getService()
            // 等待服务初始化完成
            try await ragService.initialize()
            let status = try await ragService.getIndexStatus(projectPath: projectPath)

            // 只在非索引状态下才更新状态
            if !isIndexing {
                indexStatus = status
                errorMessage = nil
                isNotInitialized = false

                if Self.verbose, let status = indexStatus {
                    RAGPlugin.logger.info(
                        "\(Self.t)RAG index status updated: \(status.projectPath), files: \(status.fileCount), chunks: \(status.chunkCount), stale: \(status.isStale)"
                    )
                }
            }
        } catch {
            // 检查是否是未初始化错误
            if let ragError = error as? RAGError, case .notInitialized = ragError {
                isNotInitialized = true
                errorMessage = nil
                if Self.verbose {
                    RAGPlugin.logger.info("\(Self.t)RAG service not initialized")
                }
                return
            }

            // 只在没有状态且不在索引中时才显示错误
            if indexStatus == nil && !isIndexing && !isNotInitialized {
                errorMessage = LumiPluginLocalization.string("Failed to get status", bundle: .module)
                if Self.verbose {
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

    public init(
        indexStatus: RAGIndexStatus?,
        isIndexing: Bool,
        progressEvent: RAGIndexProgressEvent?,
        errorMessage: String?,
        isNotInitialized: Bool
    ) {
        self.indexStatus = indexStatus
        self.isIndexing = isIndexing
        self.progressEvent = progressEvent
        self.errorMessage = errorMessage
        self.isNotInitialized = isNotInitialized
    }

    public var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("RAG Index Status", bundle: .module),
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

                Text(LumiPluginLocalization.string("Indexing...", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.primary)
            }

            if let event = progressEvent {
                VStack(alignment: .leading, spacing: 8) {
                    RAGProgressRow(label: LumiPluginLocalization.string("Scanned", bundle: .module), value: "\(event.scannedFiles) / \(event.totalFiles) \(LumiPluginLocalization.string("Files", bundle: .module))")
                    RAGProgressRow(label: LumiPluginLocalization.string("Indexed", bundle: .module), value: "\(event.indexedFiles) \(LumiPluginLocalization.string("Files", bundle: .module))")
                    RAGProgressRow(label: LumiPluginLocalization.string("Skipped", bundle: .module), value: "\(event.skippedFiles) \(LumiPluginLocalization.string("Files", bundle: .module))")
                    RAGProgressRow(label: LumiPluginLocalization.string("Document Chunks", bundle: .module), value: "\(event.chunkCount)")

                    if !event.currentFilePath.isEmpty {
                        RAGProgressRow(
                            label: LumiPluginLocalization.string("Current File", bundle: .module),
                            value: (event.currentFilePath as NSString).lastPathComponent
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func indexStatusView(_ status: RAGIndexStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RAGInfoRow(
                label: LumiPluginLocalization.string("Project", bundle: .module),
                value: (status.projectPath as NSString).lastPathComponent
            )
            RAGInfoRow(label: LumiPluginLocalization.string("File Count", bundle: .module), value: "\(status.fileCount)")
            RAGInfoRow(label: LumiPluginLocalization.string("Chunk Count", bundle: .module), value: "\(status.chunkCount)")
            RAGInfoRow(label: LumiPluginLocalization.string("Last Indexed", bundle: .module), value: formatIndexTime(status.lastIndexedAt))
            RAGInfoRow(label: LumiPluginLocalization.string("Embedding Model", bundle: .module), value: status.embeddingModel)
            RAGInfoRow(label: LumiPluginLocalization.string("Vector Dimensions", bundle: .module), value: "\(status.embeddingDimension)")
        }
    }

    @ViewBuilder
    private var notInitializedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "poweroff")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(theme.textTertiary)

            Text(LumiPluginLocalization.string("RAG Index Not Initialized", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)

            Text(LumiPluginLocalization.string("RAG service will initialize automatically when the plugin is enabled", bundle: .module))
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

            Text(LumiPluginLocalization.string("Failed to get index status", bundle: .module))
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

            Text(LumiPluginLocalization.string("Checking index status...", bundle: .module))
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
            return LumiPluginLocalization.string("Just now", bundle: .module)
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return String(format: LumiPluginLocalization.string("%lld minutes ago", bundle: .module), minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return String(format: LumiPluginLocalization.string("%lld hours ago", bundle: .module), hours)
        } else {
            let days = Int(interval / 86400)
            return String(format: LumiPluginLocalization.string("%lld days ago", bundle: .module), days)
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
