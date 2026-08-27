import AppKit
import LumiUI
import ProviderSettingView
import SwiftUI

@MainActor
public struct MLXSettingsView: View {
    @StateObject private var modelManager = MLXModelManager()
    @ObservedObject private var downloadManager = MLXDownloadManager.shared
    @State private var selectedSeries: String?
    @State private var speedLimitBytes: Int
    @State private var errorModelID: String?
    @State private var errorMessage: String?

    public init() {
        _speedLimitBytes = State(initialValue: MLXDownloadManager.shared.currentSpeedLimitBytes())
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                deviceSection
                modelSection
            }
            .padding(20)
        }
        .task {
            if selectedSeries == nil {
                selectedSeries = modelManager.series.first
            }
        }
    }

    private var deviceSection: some View {
        AppSettingsSection(title: "MLX 本地模型", spacing: 8) {
            settingRow(label: "系统内存", value: "\(modelManager.systemRAMGB) GB")
            HStack {
                Text("缓存占用")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(modelManager.formattedCacheSize)
                Button {
                    NSWorkspace.shared.open(MLXModelPaths.modelsDirectory)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("在访达中打开模型缓存目录")
            }
            downloadSpeedRow
        }
    }

    private var downloadSpeedRow: some View {
        HStack {
            Text("下载限速")
                .foregroundStyle(.secondary)
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
                downloadManager.updateDownloadSpeed(bytesPerSecond: value > 0 ? value : nil)
            }
        }
    }

    private var modelSection: some View {
        AppSettingsSection(title: "模型列表", spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                if modelManager.series.count > 1 {
                    Picker("模型系列", selection: Binding(
                        get: { selectedSeries ?? modelManager.series.first ?? "" },
                        set: { selectedSeries = $0 }
                    )) {
                        ForEach(modelManager.series, id: \.self) { series in
                            Text(series).tag(series)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let selectedSeries {
                    ForEach(modelManager.models(for: selectedSeries)) { model in
                        modelRow(model)
                        if model.id != modelManager.models(for: selectedSeries).last?.id {
                            AppSettingsDivider()
                        }
                    }
                } else {
                    Text("没有可用的模型")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    @ViewBuilder
    private func modelRow(_ model: MLXModelRegistration) -> some View {
        let isDownloading = downloadManager.downloadingModelID == model.id && downloadManager.status == .downloading
        let isPaused = downloadManager.downloadingModelID == model.id && downloadManager.status == .paused
        let isCached = !isDownloading && !isPaused && modelManager.isCached(model.id)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.displayName)
                        .font(.appBody)
                    Text("\(model.series) · 内存至少 \(model.minimumRAMGB) GB")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButtons(model: model, isDownloading: isDownloading, isPaused: isPaused, isCached: isCached)
            }

            if isDownloading || isPaused {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: downloadManager.progress.fractionCompleted)
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "pause.circle.fill" : "arrow.down.circle.fill")
                        Text(isPaused ? "已暂停" : "正在下载")
                        if let fileName = downloadManager.currentFileName {
                            Text(fileName).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        Text(downloadManager.progress.percentLabel)
                        if !downloadManager.progress.speedLabel.isEmpty && isDownloading {
                            Text(downloadManager.progress.speedLabel)
                        }
                    }
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                }
            }

            if errorModelID == model.id, let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appCaption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func actionButtons(
        model: MLXModelRegistration,
        isDownloading: Bool,
        isPaused: Bool,
        isCached: Bool
    ) -> some View {
        if isCached {
            Button("删除") { delete(model.id) }
                .buttonStyle(.bordered)
        } else if isDownloading {
            Button { downloadManager.pause() } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(.bordered)
            .help("暂停下载")
        } else if isPaused {
            Button { Task { await downloadManager.resume() } } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.bordered)
            .help("继续下载")
            Button { downloadManager.cancel() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("取消下载")
        } else {
            Button("下载") { startDownload(model.id) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func startDownload(_ modelID: String) {
        errorModelID = nil
        errorMessage = nil
        Task {
            await downloadManager.download(modelID: modelID)
            modelManager.refresh()
            if case .failed(let message) = downloadManager.status {
                errorModelID = modelID
                errorMessage = message
            }
        }
    }

    private func delete(_ modelID: String) {
        errorModelID = nil
        errorMessage = nil
        do {
            try modelManager.deleteModel(modelID)
        } catch {
            errorModelID = modelID
            errorMessage = error.localizedDescription
        }
    }
}
