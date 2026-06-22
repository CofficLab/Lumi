import LumiCoreKit
import LumiUI
import SwiftUI

@available(macOS 14.0, *)
public struct MLXLocalProviderSettingsView: View {
    @LumiTheme private var theme

    @StateObject private var modelManager = MLXModelManager()
    @StateObject private var downloadManager = MLXDownloadManager()
    @StateObject private var inferenceService = MLXInferenceService()

    @State private var actionError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            machineInfoCard
            modelListCard

            if let actionError {
                Text(actionError)
                    .font(.appCaption)
                    .foregroundColor(theme.error)
            }
        }
    }

    private var machineInfoCard: some View {
        AppSettingsSection(title: "设备信息", spacing: 8) {
            HStack {
                Text("系统内存")
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text("\(modelManager.systemRAM) GB")
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
            }
            HStack {
                Text("缓存占用")
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Text(modelManager.formattedCacheSize)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
            }
        }
    }

    private var modelListCard: some View {
        AppSettingsSection(
            title: "本地模型",
            subtitle: "下载后在本地运行，无需 API Key",
            spacing: 12
        ) {
            VStack(spacing: 0) {
                ForEach(modelManager.availableModels()) { model in
                    modelRow(model)
                }
            }
        }
    }

    @ViewBuilder
    private func modelRow(_ model: LocalModelInfo) -> some View {
        let isCached = modelManager.isModelCached(id: model.id)
        let isDownloading = downloadManager.downloadingModelId == model.id
        let isLoaded = inferenceService.currentModelId == model.id
        let isLoading = inferenceService.state == .loading && inferenceService.currentModelId == model.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    Text("体积 \(model.size) · 内存 ≥ \(model.minRAM) GB")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if isCached {
                    AppButton("加载", style: .secondary, size: .small) {
                        Task { await loadModel(model.id) }
                    }
                    .disabled(isLoading || isLoaded)

                    if isLoaded {
                        AppButton("卸载", style: .secondary, size: .small) {
                            Task { await unloadModel() }
                        }
                    }
                } else {
                    AppButton(isDownloading ? "下载中" : "下载", style: .secondary, size: .small) {
                        Task { await downloadModel(model.id) }
                    }
                    .disabled(isDownloading)
                }
            }

            if isDownloading {
                ProgressView(value: downloadManager.progress.fractionCompleted)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 6)

        if model.id != modelManager.availableModels().last?.id {
            AppSettingsDivider()
        }
    }

    @MainActor
    private func downloadModel(_ modelID: String) async {
        actionError = nil
        await downloadManager.download(modelId: modelID)
        modelManager.refreshCachedModels()
        modelManager.updateCacheSize()
        if case .failed(let message) = downloadManager.status {
            actionError = message
        }
    }

    @MainActor
    private func loadModel(_ modelID: String) async {
        actionError = nil
        do {
            try await inferenceService.loadModel(id: modelID)
        } catch {
            actionError = error.localizedDescription
        }
    }

    @MainActor
    private func unloadModel() async {
        actionError = nil
        await inferenceService.unloadModel()
    }
}
