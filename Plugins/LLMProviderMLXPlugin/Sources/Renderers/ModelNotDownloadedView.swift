import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

/// 「模型未下载」时展示的内联下载界面。
///
/// 错误消息携带目标模型 ID（`message.modelName`），本视图据此：
/// - 展示模型名/体积/内存要求；
/// - 提供下载按钮（暂停/继续/取消）；
/// - 下载完成后变为「重新发送」按钮（复用 `.lumiResendMessage` 通知重发该错误消息对应的用户消息）。
///
/// 实时进度由全局单例 `MLXDownloadManager.shared` 驱动（与设置页一致）。
struct ModelNotDownloadedView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    @ObservedObject private var downloadManager = MLXDownloadManager.shared

    /// 本条消息指向的模型 ID（即发送时选择、但未下载的模型）。
    private var modelID: String { message.modelName ?? "" }

    private var model: LocalModelInfo? { MLXModels.model(id: modelID) }
    private var displayName: String { model?.displayName ?? modelID }

    /// 该模型当前的下载状态（仅当下载管理器正在处理「本模型」时为下载中/暂停）。
    private var isDownloading: Bool {
        downloadManager.downloadingModelId == modelID && downloadManager.status == .downloading
    }

    private var isPaused: Bool {
        downloadManager.downloadingModelId == modelID && downloadManager.status == .paused
    }

    /// 下载是否已失败（仅针对本模型）。
    private var isFailed: Bool {
        if case .failed = downloadManager.status {
            return downloadManager.downloadingModelId == modelID
        }
        return false
    }

    /// 模型是否已缓存完整（下载完成）。
    private var isDownloaded: Bool {
        // 下载中/暂停时，部分文件可能被误判，排除这两种状态。
        guard !isDownloading, !isPaused else { return false }
        return MLXModels.isModelCached(id: modelID)
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                header

                if isDownloading || isPaused {
                    progressSection
                } else if isDownloaded {
                    completedSection
                } else {
                    notDownloadedSection
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(
                format: LumiPluginLocalization.string("%@ is not downloaded", bundle: .module),
                displayName
            ))
            .font(.appCallout)
            .fontWeight(.semibold)
            .foregroundColor(theme.textPrimary)

            if let model {
                Text(String(
                    format: LumiPluginLocalization.string("体积 %@ · 内存 ≥ %d GB", bundle: .module),
                    model.size, model.minRAM
                ))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            } else {
                Text(modelID)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var notDownloadedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LumiPluginLocalization.string(
                "Download this model to chat with it locally. You can resend your message once the download finishes.",
                bundle: .module
            ))
            .font(.appCaption)
            .foregroundColor(theme.textSecondary)

            if isFailed, case .failed(let detail) = downloadManager.status {
                Text(String(
                    format: LumiPluginLocalization.string("Download failed: %@", bundle: .module),
                    detail
                ))
                .font(.appCaption)
                .foregroundColor(theme.error)
            }

            HStack(spacing: 8) {
                AppButton(
                    LumiPluginLocalization.string("Download", bundle: .module),
                    systemImage: "arrow.down.circle",
                    style: .primary,
                    size: .small
                ) {
                    Task { await downloadManager.download(modelId: modelID) }
                }
                .disabled(modelID.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: downloadManager.progress.fractionCompleted)
                .controlSize(.small)

            HStack(spacing: 6) {
                Image(systemName: isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                    .font(.caption2)
                    .foregroundColor(isPaused ? theme.warning : theme.textSecondary)

                if let fileName = downloadManager.currentFileName {
                    Text((isPaused
                          ? LumiPluginLocalization.string("已暂停", bundle: .module)
                          : LumiPluginLocalization.string("正在下载", bundle: .module))
                         + " " + fileName)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(LumiPluginLocalization.string("准备下载...", bundle: .module))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer(minLength: 0)

                Text("\(downloadManager.progress.completedFiles)/\(downloadManager.progress.totalFiles) · \(downloadManager.progress.percentLabel)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                if isDownloading, !downloadManager.progress.speedLabel.isEmpty {
                    Text(downloadManager.progress.speedLabel)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }

            HStack(spacing: 8) {
                if isDownloading {
                    AppButton(
                        systemImage: "pause.fill",
                        style: .secondary,
                        size: .small
                    ) {
                        downloadManager.pause()
                    }
                    .help(LumiPluginLocalization.string("暂停下载", bundle: .module))
                } else if isPaused {
                    AppButton(
                        systemImage: "play.fill",
                        style: .secondary,
                        size: .small
                    ) {
                        Task { await downloadManager.resume() }
                    }
                    .help(LumiPluginLocalization.string("继续下载", bundle: .module))
                }

                AppButton(
                    systemImage: "xmark",
                    style: .ghost,
                    size: .small
                ) {
                    downloadManager.cancel()
                }
                .help(LumiPluginLocalization.string("取消下载", bundle: .module))
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LumiPluginLocalization.string("Download complete.", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            AppButton(
                LumiPluginLocalization.string("Resend", bundle: .module),
                systemImage: "arrow.clockwise",
                style: .primary,
                size: .small
            ) {
                resendMessage()
            }
        }
    }

    // MARK: - Actions

    /// 复用 `.lumiResendMessage` 通知重发该消息对应的用户输入（与错误消息上的「重发」按钮一致）。
    private func resendMessage() {
        NotificationCenter.default.post(
            name: .lumiResendMessage,
            object: nil,
            userInfo: [
                LumiMessageSavedNotification.messageIDKey: message.id,
                LumiMessageSavedNotification.conversationIDKey: message.conversationID,
            ]
        )
    }
}
