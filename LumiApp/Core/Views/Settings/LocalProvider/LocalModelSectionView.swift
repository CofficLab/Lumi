import SwiftUI
import AppKit
import Darwin

/// 本地供应商模型区块：已加载模型、本机信息、系列 Tab、模型列表（下载/加载/卸载）
struct LocalModelSectionView: View {
    let localProvider: (any SuperLocalLLMProvider)?
    @Binding var selectedModel: String
    @Binding var selectedSeriesName: String

    let localAvailableModels: [LocalModelInfo]
    let localCachedIds: Set<String>
    let localModelsLoading: Bool
    let localActionError: String?
    let downloadingModelId: String?
    let localDownloadStatus: LocalDownloadStatus
    let loadedModelId: String?
    let loadingModelId: String?
    let showUnloadSuccess: Bool

    let onSaveModel: () -> Void
    let onDownload: (String) async -> Void
    let onLoad: (String) async -> Void
    let onUnload: () async -> Void
    let onOpenCacheDirectory: () -> Void

    private enum MainTab {
        case downloaded
        case all
    }

    @State private var selectedMainTab: MainTab = .downloaded

    private var localModelsBySeries: [LocalModelsSection] {
        let fallbackSeries = "其他"
        let grouped = Dictionary(grouping: localAvailableModels) { $0.series ?? fallbackSeries }
        return grouped.keys.sorted().map { LocalModelsSection(seriesName: $0, models: grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            errorAndFeedbackBlock
            if localModelsLoading {
                loadingPlaceholder
            } else {
                switch selectedMainTab {
                case .downloaded:
                    localMachineInfoBlock
                    let downloadedModels = localAvailableModels.filter { localCachedIds.contains($0.id) }
                    if !downloadedModels.isEmpty {
                        Label("已下载", systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(downloadedModels) { model in
                                LocalModelRow(
                                    model: model,
                                    isCached: true,
                                    isSelected: false,
                                    isDownloading: false,
                                    downloadStatus: nil,
                                    isDownloadDisabled: false,
                                    isThisModelLoaded: loadedModelId == model.id,
                                    hasAnyModelLoaded: loadedModelId != nil,
                                    isLoading: loadingModelId == model.id,
                                    isLoadDisabled: loadingModelId != nil,
                                    onSelect: { },
                                    onDownload: { },
                                    onLoad: { Task { await onLoad(model.id) } },
                                    onUnload: { Task { await onUnload() } }
                                )
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 16))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.6))
                            Text("暂无已下载的模型")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .all:
                    availableModelsList
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                SeriesTabButton(title: "已下载", isSelected: selectedMainTab == .downloaded) {
                    selectedMainTab = .downloaded
                }
                SeriesTabButton(title: "模型列表", isSelected: selectedMainTab == .all) {
                    selectedMainTab = .all
                }
            }
            Spacer()
            Button(action: onOpenCacheDirectory) {
                Label("打开下载目录", systemImage: "folder")
                    .font(.system(size: 12, weight: .regular))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("打开下载目录")
            .accessibilityHint("在访达中打开本地模型缓存文件夹")
        }
    }

    @ViewBuilder
    private var errorAndFeedbackBlock: some View {
        if let errorMessage = localActionError {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FF453A"))
                Text(errorMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "FF453A"))
            }
        }
        if showUnloadSuccess {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "7C6FFF"))
                Text("已卸载")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "7C6FFF"))
            }
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Label("正在加载模型列表…", systemImage: "list.bullet")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var availableModelsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 系列 Tab
            HStack(spacing: 8) {
                ForEach(localModelsBySeries) { section in
                    SeriesTabButton(
                        title: section.seriesName,
                        isSelected: selectedSeriesName == section.seriesName
                    ) {
                        selectedSeriesName = section.seriesName
                    }
                }
            }
            // 模型列表（展示该系列下全部模型，已下载/未下载均显示）
            if let section = localModelsBySeries.first(where: { $0.seriesName == selectedSeriesName }) ?? localModelsBySeries.first {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.models) { model in
                        let isCached = localCachedIds.contains(model.id)
                        LocalModelRow(
                            model: model,
                            isCached: isCached,
                            isSelected: false,
                            isDownloading: downloadingModelId == model.id,
                            downloadStatus: downloadingModelId == model.id ? localDownloadStatus : nil,
                            isDownloadDisabled: downloadingModelId != nil,
                            isThisModelLoaded: loadedModelId == model.id,
                            hasAnyModelLoaded: loadedModelId != nil,
                            isLoading: loadingModelId == model.id,
                            isLoadDisabled: loadingModelId != nil,
                            onSelect: { },
                            onDownload: { Task { await onDownload(model.id) } },
                            onLoad: { Task { await onLoad(model.id) } },
                            onUnload: { Task { await onUnload() } }
                        )
                    }
                }
            }
        }
    }

    private var localMachineInfoBlock: some View {
        LocalMachineInfoView()
    }

}
