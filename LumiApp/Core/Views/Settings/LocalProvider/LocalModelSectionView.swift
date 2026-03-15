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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
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
                            .font(DesignTokens.Typography.callout)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
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
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "tray")
                                .font(.system(size: 16))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                            Text("暂无已下载的模型")
                                .font(DesignTokens.Typography.caption1)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        .padding(DesignTokens.Spacing.sm)
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
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    selectedMainTab = .downloaded
                } label: {
                    Text("已下载")
                        .font(DesignTokens.Typography.caption1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedMainTab == .downloaded ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
                        )
                        .foregroundColor(selectedMainTab == .downloaded ? .white : DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    selectedMainTab = .all
                } label: {
                    Text("模型列表")
                        .font(DesignTokens.Typography.caption1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedMainTab == .all ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
                        )
                        .foregroundColor(selectedMainTab == .all ? .white : DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: onOpenCacheDirectory) {
                Label("打开下载目录", systemImage: "folder")
                    .font(DesignTokens.Typography.caption1)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("打开下载目录")
            .accessibilityHint("在访达中打开本地模型缓存文件夹")
        }
    }

    @ViewBuilder
    private var errorAndFeedbackBlock: some View {
        if let errorMessage = localActionError {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.error)
                Text(errorMessage)
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.error)
            }
        }
        if showUnloadSuccess {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                Text("已卸载")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.primary)
            }
        }
    }

    private var loadingPlaceholder: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
            Label("正在加载模型列表…", systemImage: "list.bullet")
                .font(DesignTokens.Typography.caption1)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var availableModelsList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 系列 Tab
            HStack(spacing: DesignTokens.Spacing.sm) {
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
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
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

