import AppKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

@available(macOS 14.0, *)
public struct MLXLocalProviderSettingsView: View {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "ui.mlx")

    @LumiTheme private var theme

    @StateObject private var modelManager = MLXModelManager()
    @ObservedObject private var downloadManager = MLXDownloadManager.shared
    @StateObject private var inferenceService = MLXInferenceService()

    @State private var actionError: String?
    @State private var errorModelId: String?
    @State private var selectedSeriesId: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            machineInfoCard
            modelListCard
        }
    }

    private var machineInfoCard: some View {
        AppSettingsSection(
            title: LumiPluginLocalization.string("设备信息", bundle: .module),
            spacing: 8
        ) {
            HStack {
                Text(LumiPluginLocalization.string("系统内存", bundle: .module))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(modelManager.systemRAM) GB")
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
            }
            HStack {
                Text(LumiPluginLocalization.string("缓存占用", bundle: .module))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(modelManager.formattedCacheSize)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                AppButton(systemImage: "folder", style: .ghost, size: .small) {
                    openCacheDirectory()
                }
                .help(LumiPluginLocalization.string("在访达中打开缓存目录", bundle: .module))
            }
        }
    }

    private func openCacheDirectory() {
        let url = MLXModels.modelsCacheBaseDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private var modelListCard: some View {
        let allSeries = modelManager.modelsBySeries()
        let selectedSeries = allSeries.first { $0.id == selectedSeriesId } ?? allSeries.first

        return AppSettingsSection(
            title: LumiPluginLocalization.string("本地模型", bundle: .module),
            subtitle: LumiPluginLocalization.string("下载后在本地运行，无需 API Key", bundle: .module),
            spacing: 12
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 8) {
                        ForEach(allSeries) { series in
                            seriesTab(series, isSelected: series.id == selectedSeries?.id)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if let series = selectedSeries {
                    VStack(spacing: 0) {
                        ForEach(series.models) { model in
                            modelRow(model)
                            if model.id != series.models.last?.id {
                                AppSettingsDivider()
                            }
                        }
                    }
                    .transition(.opacity)
                } else {
                    Text(LumiPluginLocalization.string("没有可用的模型", bundle: .module))
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
            .onAppear {
                if selectedSeriesId == nil, let firstSeries = allSeries.first {
                    selectedSeriesId = firstSeries.id
                }
            }
            .onChange(of: allSeries) { _, newSeries in
                if let firstSeries = newSeries.first {
                    selectedSeriesId = firstSeries.id
                }
            }
        }
    }

    @ViewBuilder
    private func seriesTab(_ series: MLXModelManager.ModelSeries, isSelected: Bool) -> some View {
        Button {
            selectedSeriesId = series.id
        } label: {
            HStack(spacing: 6) {
                Text(series.name)
                    .font(.appCaption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(series.models.count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? theme.primary.opacity(0.2) : theme.overlay)
                    )
            }
            .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func modelRow(_ model: LocalModelInfo) -> some View {
        let isDownloading = downloadManager.downloadingModelId == model.id && downloadManager.status == .downloading
        let isPaused = downloadManager.downloadingModelId == model.id && downloadManager.status == .paused
        // 正在下载/暂停的模型不算已缓存：下载中途的部分文件可能被 isModelCached 误判为已缓存
        // （它只检查 safetensors 是否 ≥1MB，不校验完整性），导致按钮在下载中途错乱地变成「加载」。
        let isActiveDownload = isDownloading || isPaused
        let isCached = !isActiveDownload && modelManager.isModelCached(id: model.id)
        let isLoaded = inferenceService.currentModelId == model.id
        let isLoading = inferenceService.state == .loading && inferenceService.currentModelId == model.id
        let hasError = errorModelId == model.id && actionError != nil

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    Text(String(
                        format: LumiPluginLocalization.string("体积 %@ · 内存 ≥ %d GB", bundle: .module),
                        model.size, model.minRAM
                    ))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if isCached {
                    AppButton(
                        LumiPluginLocalization.string("加载", bundle: .module),
                        style: .secondary,
                        size: .small
                    ) {
                        Task { await loadModel(model.id) }
                    }
                    .disabled(isLoading || isLoaded)

                    if isLoaded {
                        AppButton(
                            LumiPluginLocalization.string("卸载", bundle: .module),
                            style: .secondary,
                            size: .small
                        ) {
                            Task { await unloadModel() }
                        }
                    }
                } else {
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

                        AppButton(
                            systemImage: "xmark",
                            style: .ghost,
                            size: .small
                        ) {
                            downloadManager.cancel()
                        }
                        .help(LumiPluginLocalization.string("取消下载", bundle: .module))
                    } else {
                        AppButton(
                            LumiPluginLocalization.string("下载", bundle: .module),
                            style: .secondary,
                            size: .small
                        ) {
                            Task { await downloadModel(model.id) }
                        }
                    }
                }
            }

            if isDownloading || isPaused {
                VStack(alignment: .leading, spacing: 4) {
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

                        if downloadManager.currentFileSize > 0 {
                            let downloaded = downloadManager.currentFileDownloadedBytes
                            let total = downloadManager.currentFileSize
                            if downloaded > 0 {
                                Text("\(formattedFileSize(downloaded)) / \(formattedFileSize(total))")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            } else {
                                Text(formattedFileSize(total))
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        Text("\(downloadManager.progress.completedFiles)/\(downloadManager.progress.totalFiles)")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }

            if hasError, let errorMsg = actionError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(theme.error)
                    Text(errorMsg)
                        .font(.appCaption)
                        .foregroundColor(theme.error)
                    Spacer()
                    AppButton(systemImage: "doc.on.doc", style: .ghost, size: .small) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(errorMsg, forType: .string)
                    }
                    .help(LumiPluginLocalization.string("复制错误信息", bundle: .module))
                }
            }
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func downloadModel(_ modelID: String) async {
        Self.logger.info("🟢 UI: 开始下载模型 \(modelID)")
        actionError = nil
        errorModelId = nil

        await downloadManager.download(modelId: modelID)

        Self.logger.info("🟢 UI: 下载任务结束，状态：\(String(describing: downloadManager.status))")

        modelManager.refreshCachedModels()
        modelManager.updateCacheSize()

        if case .failed(let message) = downloadManager.status {
            Self.logger.error("❌ UI: 下载失败，错误信息：\(message)")
            actionError = message
            errorModelId = modelID
        } else if case .completed = downloadManager.status {
            Self.logger.info("✅ UI: 下载成功完成")
            actionError = nil
            errorModelId = nil
        }
    }

    @MainActor
    private func loadModel(_ modelID: String) async {
        actionError = nil
        errorModelId = nil
        do {
            try await inferenceService.loadModel(id: modelID)
        } catch {
            actionError = error.localizedDescription
            errorModelId = modelID
        }
    }

    @MainActor
    private func unloadModel() async {
        actionError = nil
        errorModelId = nil
        await inferenceService.unloadModel()
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
