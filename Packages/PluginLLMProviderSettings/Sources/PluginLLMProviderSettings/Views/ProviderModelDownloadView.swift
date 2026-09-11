#if os(macOS)
import AppKit
#endif
import Foundation
import KitLLM
import LumiUI
import SwiftUI

/// 支持模型下载的供应商通用下载视图。
///
/// 该视图只依赖 KitLLM 的下载能力协议，不感知具体供应商实现。
@MainActor
struct ProviderModelDownloadView: View {
    @LumiTheme private var theme

    private let downloader: any LLMModelDownloadProviding
    private let models: [LLMModelInfo]
    private let onSelectModel: (String) -> Void
    private let isModelSelected: (String) -> Bool
    @ObservedObject private var viewModel: ProviderModelDownloadViewModel
    @State private var speedLimitBytes: Int
    @State private var errorModelID: String?
    @State private var errorMessage: String?

    init(
        models: [LLMModelInfo],
        downloader: any LLMModelDownloadProviding,
        viewModel: ProviderModelDownloadViewModel,
        onSelectModel: @escaping (String) -> Void,
        isModelSelected: @escaping (String) -> Bool
    ) {
        self.models = models
        self.downloader = downloader
        self.viewModel = viewModel
        self.onSelectModel = onSelectModel
        self.isModelSelected = isModelSelected
        _speedLimitBytes = State(initialValue: viewModel.downloadState.speedLimitBytesPerSecond ?? 0)
    }

    var body: some View {
        AppSettingSection(title: "模型下载") {
            VStack(spacing: 0) {
                cacheRow
                
                Divider()
                    .padding(.vertical, 8)
                
                downloadSpeedRow
            }
        }
        
        AppSettingSection(title: "可用模型") {
            VStack(spacing: 0) {
                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    modelRow(model)
                }
            }
        }
        .onAppear { downloader.refreshDownloadState() }
    }

    private var downloadState: LLMModelDownloadState { viewModel.downloadState }

    private var cacheRow: some View {
        AppSettingRow(
            title: "缓存占用",
            description: ByteCountFormatter.string(fromByteCount: downloadState.cacheSizeBytes, countStyle: .file),
            icon: "internaldrive"
        ) {
            #if os(macOS)
            AppButton("打开", systemImage: "folder", style: .secondary, size: .small) {
                NSWorkspace.shared.open(downloader.modelCacheDirectoryURL)
            }
            #endif
        }
    }

    private var downloadSpeedRow: some View {
        AppSettingRow(
            title: "下载限速",
            description: speedLimitDescription,
            icon: "speedometer"
        ) {
            Picker("", selection: $speedLimitBytes) {
                Text("不限速").tag(0)
                Text("512 KB/s").tag(512 * 1024)
                Text("1 MB/s").tag(1024 * 1024)
                Text("2 MB/s").tag(2 * 1024 * 1024)
                Text("5 MB/s").tag(5 * 1024 * 1024)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 120)
            .onChange(of: speedLimitBytes) { _, value in
                downloader.setDownloadSpeedLimit(bytesPerSecond: value > 0 ? value : nil)
            }
        }
    }
    
    private var speedLimitDescription: String {
        switch speedLimitBytes {
        case 0: "不限速"
        case 512 * 1024: "512 KB/s"
        case 1024 * 1024: "1 MB/s"
        case 2 * 1024 * 1024: "2 MB/s"
        case 5 * 1024 * 1024: "5 MB/s"
        default: "自定义"
        }
    }

    @ViewBuilder
    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isDownloading = downloadState.modelID == model.id && downloadState.status == .downloading
        let isPaused = downloadState.modelID == model.id && downloadState.status == .paused
        let isCached = !isDownloading && !isPaused && downloadState.downloadedModelIDs.contains(model.id)
        let isSelected = isModelSelected(model.id)
        
        // 根据状态确定图标
        let rowIcon: String = {
            if isSelected { return "checkmark.circle.fill" }
            if isDownloading { return "arrow.down.circle" }
            if isPaused { return "pause.circle" }
            if isCached { return "externaldrive.fill" }
            return "arrow.down.circle"
        }()
        
        // 根据状态确定描述
        let rowDescription: String? = {
            if isDownloading { return "正在下载..." }
            if isPaused { return "已暂停" }
            if isCached { return "已下载" }
            return nil
        }()
        
        AppSettingRow(
            title: model.displayName,
            description: rowDescription ?? model.id,
            icon: rowIcon
        ) {
            HStack(spacing: 6) {
                if isDownloading || isPaused {
                    // 下载进度
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(downloadState.progress.fractionCompleted * 100))%")
                            .font(.appMicro)
                            .foregroundStyle(theme.textSecondary)
                        if isDownloading, let speed = downloadState.progress.speedBytesPerSecond, speed > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s")
                                .font(.appMicro)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                
                // 操作按钮
                actionButtons(
                    modelID: model.id,
                    isDownloading: isDownloading,
                    isPaused: isPaused,
                    isCached: isCached
                )
            }
        }
        .onTapGesture {
            if isCached {
                onSelectModel(model.id)
            }
        }
        
        // 下载进度条（在行下方）
        if isDownloading || isPaused {
            ProgressView(value: downloadState.progress.fractionCompleted)
                .tint(theme.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        
        // 错误信息
        if errorModelID == model.id, let errorMessage {
            Text(errorMessage)
                .font(.appMicro)
                .foregroundStyle(theme.error)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func actionButtons(
        modelID: String,
        isDownloading: Bool,
        isPaused: Bool,
        isCached: Bool
    ) -> some View {
        if isCached {
            AppButton("删除", systemImage: "trash", style: .destructive, size: .small) {
                delete(modelID)
            }
        } else if isDownloading {
            AppButton(systemImage: "pause.fill", style: .tonal, size: .small) {
                downloader.pauseDownload()
            }
            .help("暂停下载")
        } else if isPaused {
            AppButton(systemImage: "play.fill", style: .tonal, size: .small) {
                Task { await downloader.resumeDownload() }
            }
            .help("继续下载")
            AppButton(systemImage: "xmark", style: .ghost, size: .small) {
                downloader.cancelDownload()
            }
            .help("取消下载")
        } else {
            AppButton("下载", systemImage: "arrow.down.circle", style: .primary, size: .small) {
                startDownload(modelID)
            }
        }
    }

    private func startDownload(_ modelID: String) {
        errorModelID = nil
        errorMessage = nil
        Task {
            await downloader.download(modelID: modelID)
            downloader.refreshDownloadState()
            if case .failed(let message) = downloader.downloadState.status {
                errorModelID = modelID
                errorMessage = message
            }
        }
    }

    private func delete(_ modelID: String) {
        errorModelID = nil
        errorMessage = nil
        do {
            try downloader.deleteDownloadedModel(modelID: modelID)
            downloader.refreshDownloadState()
        } catch {
            errorModelID = modelID
            errorMessage = error.localizedDescription
        }
    }
}
