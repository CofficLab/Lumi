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
    @State private var downloadState: LLMModelDownloadState
    @State private var speedLimitBytes: Int
    @State private var errorModelID: String?
    @State private var errorMessage: String?

    init(
        models: [LLMModelInfo],
        downloader: any LLMModelDownloadProviding,
        onSelectModel: @escaping (String) -> Void,
        isModelSelected: @escaping (String) -> Bool
    ) {
        self.models = models
        self.downloader = downloader
        self.onSelectModel = onSelectModel
        self.isModelSelected = isModelSelected
        _downloadState = State(initialValue: downloader.downloadState)
        _speedLimitBytes = State(initialValue: downloader.downloadState.speedLimitBytesPerSecond ?? 0)
    }

    var body: some View {
        AppSettingsSection(title: "模型下载", subtitle: "下载后即可选择并使用本地模型") {
            cacheRow
            downloadSpeedRow
            VStack(spacing: 0) {
                ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
                    modelRow(model)
                    if index < models.count - 1 {
                        AppDivider()
                    }
                }
            }
        }
        .onAppear { downloader.refreshDownloadState() }
        .onReceive(downloader.downloadStatePublisher) { state in
            downloadState = state
        }
    }

    private var cacheRow: some View {
        HStack {
            Text("缓存占用")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: downloadState.cacheSizeBytes, countStyle: .file))
                .font(.appCaption)
                .foregroundStyle(theme.textPrimary)
            #if os(macOS)
            Button {
                NSWorkspace.shared.open(downloader.modelCacheDirectoryURL)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("在访达中打开模型缓存目录")
            #endif
        }
    }

    private var downloadSpeedRow: some View {
        HStack {
            Text("下载限速")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Picker("下载限速", selection: $speedLimitBytes) {
                Text("不限速").tag(0)
                Text("512 KB/s").tag(512 * 1024)
                Text("1 MB/s").tag(1024 * 1024)
                Text("2 MB/s").tag(2 * 1024 * 1024)
                Text("5 MB/s").tag(5 * 1024 * 1024)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: speedLimitBytes) { _, value in
                downloader.setDownloadSpeedLimit(bytesPerSecond: value > 0 ? value : nil)
            }
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func modelRow(_ model: LLMModelInfo) -> some View {
        let isDownloading = downloadState.modelID == model.id && downloadState.status == .downloading
        let isPaused = downloadState.modelID == model.id && downloadState.status == .paused
        let isCached = !isDownloading && !isPaused && downloadState.downloadedModelIDs.contains(model.id)
        let isSelected = isModelSelected(model.id)

        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Button {
                    guard isCached else { return }
                    onSelectModel(model.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? theme.primary : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!isCached)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                    Text(model.id)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                actionButtons(modelID: model.id, isDownloading: isDownloading, isPaused: isPaused, isCached: isCached)
            }

            if isDownloading || isPaused {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: downloadState.progress.fractionCompleted)
                    HStack(spacing: 6) {
                        Image(systemName: isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                        Text(isPaused ? "已暂停" : "正在下载")
                        if let fileName = downloadState.currentFileName {
                            Text(fileName).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text("\(Int(downloadState.progress.fractionCompleted * 100))%")
                        if isDownloading, let speed = downloadState.progress.speedBytesPerSecond, speed > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s")
                        }
                    }
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                }
                .padding(.leading, 30)
            }

            if errorModelID == model.id, let errorMessage {
                Text(errorMessage)
                    .font(.appMicro)
                    .foregroundStyle(theme.error)
                    .padding(.leading, 30)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func actionButtons(
        modelID: String,
        isDownloading: Bool,
        isPaused: Bool,
        isCached: Bool
    ) -> some View {
        if isCached {
            Button("删除") { delete(modelID) }
                .buttonStyle(.bordered)
        } else if isDownloading {
            Button { downloader.pauseDownload() } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.bordered)
            .help("暂停下载")
        } else if isPaused {
            Button { Task { await downloader.resumeDownload() } } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.bordered)
            .help("继续下载")
            Button { downloader.cancelDownload() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("取消下载")
        } else {
            Button("下载") { startDownload(modelID) }
                .buttonStyle(.borderedProminent)
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
