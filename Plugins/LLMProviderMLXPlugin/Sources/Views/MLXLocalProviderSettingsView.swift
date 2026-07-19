import AppKit
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

@available(macOS 14.0, *)
public struct MLXLocalProviderSettingsView: View, SuperLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "ui.mlx")

    @LumiTheme private var theme

    @StateObject private var modelManager = MLXModelManager()
    @ObservedObject private var downloadManager = MLXDownloadManager.shared
    @StateObject private var inferenceService = MLXInferenceService()

    @State private var actionError: String?
    @State private var errorModelId: String?
    @State private var selectedSeriesId: String?
    /// 下载限速档位（字节/秒）。0 表示不限速。
    @State private var speedLimitBytes: Int = MLXDownloadManager.shared.currentSpeedLimitBytes()

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
            downloadSpeedRow
        }
    }

    /// 下载限速选择行。
    ///
    /// 限速值存储为字节/秒（0 = 不限速），由 `MLXDownloadManager` 同步到底层
    /// DownloadKit 限速器，下载进行中调整也即时生效。
    private var downloadSpeedRow: some View {
        HStack {
            Text(LumiPluginLocalization.string("下载限速", bundle: .module))
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Picker("", selection: $speedLimitBytes) {
                Text(LumiPluginLocalization.string("不限速", bundle: .module)).tag(0)
                Text("512 KB/s").tag(512 * 1024)
                Text("1 MB/s").tag(1024 * 1024)
                Text("2 MB/s").tag(2 * 1024 * 1024)
                Text("5 MB/s").tag(5 * 1024 * 1024)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 140)
            .onChange(of: speedLimitBytes) { _, newValue in
                let bytesPerSecond = newValue > 0 ? newValue : nil
                downloadManager.updateDownloadSpeed(bytesPerSecond: bytesPerSecond)
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
                // 系列选择器用流式布局：全部平铺、一行放不下自动换行，避免横向滚动条。
                FlowLayout(spacing: 8) {
                    ForEach(allSeries) { series in
                        seriesTab(series, isSelected: series.id == selectedSeries?.id)
                    }
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
            .onChange(of: allSeries) { oldSeries, newSeries in
                // 列表变化时（如 RAM 改变导致可用模型增减），仅当用户当前选中的系列
                // 已不存在才回退到第一个；否则保留用户选择，避免每次刷新都重置 tab。
                // 旧逻辑无脑取 newSeries.first，会反复把选中重置回第一个系列。
                if selectedSeriesId.map({ id in newSeries.contains { $0.id == id } }) == false {
                    selectedSeriesId = newSeries.first?.id ?? oldSeries.first?.id
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
                    if isLoaded {
                        AppButton(
                            LumiPluginLocalization.string("卸载", bundle: .module),
                            style: .secondary,
                            size: .small
                        ) {
                            Task { await unloadModel() }
                        }
                    }
                    AppButton(
                        LumiPluginLocalization.string("删除", bundle: .module),
                        style: .ghost,
                        size: .small
                    ) {
                        Task { await deleteModel(model.id) }
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

                        // 实时下载速度（暂停时 speed 被清空，仅下载中显示）
                        if isDownloading, !downloadManager.progress.speedLabel.isEmpty {
                            Text(downloadManager.progress.speedLabel)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
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
        Self.logger.info("\(Self.t)🟢 UI: 开始下载模型 \(modelID)")
        actionError = nil
        errorModelId = nil

        await downloadManager.download(modelId: modelID)

        Self.logger.info("\(Self.t)🟢 UI: 下载任务结束，状态：\(String(describing: downloadManager.status))")

        modelManager.refreshCachedModels()
        modelManager.updateCacheSize()

        if case .failed(let message) = downloadManager.status {
            Self.logger.error("\(Self.t)❌ UI: 下载失败，错误信息：\(message)")
            actionError = message
            errorModelId = modelID
        } else if case .completed = downloadManager.status {
            Self.logger.info("\(Self.t)✅ UI: 下载成功完成")
            actionError = nil
            errorModelId = nil
        }
    }

    @MainActor
    private func unloadModel() async {
        actionError = nil
        errorModelId = nil
        inferenceService.unloadModel()
    }

    @MainActor
    private func deleteModel(_ modelID: String) async {
        actionError = nil
        errorModelId = nil

        // 如果模型正在使用，先卸载
        if inferenceService.currentModelId == modelID {
            inferenceService.unloadModel()
        }

        do {
            try modelManager.deleteModel(id: modelID)
        } catch {
            actionError = error.localizedDescription
            errorModelId = modelID
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Flow Layout

/// 简单的流式布局：子视图横向依次排列，一行放不下时自动换到下一行。
///
/// 用于模型系列选择器，避免横向滚动条，让所有系列标签全部铺开展示。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
