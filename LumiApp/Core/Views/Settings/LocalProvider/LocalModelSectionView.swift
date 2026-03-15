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

    private var localModelsBySeries: [LocalModelsSection] {
        let fallbackSeries = "其他"
        let grouped = Dictionary(grouping: localAvailableModels) { $0.series ?? fallbackSeries }
        return grouped.keys.sorted().map { LocalModelsSection(seriesName: $0, models: grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            headerRow
            // 1. 本机配置
            localMachineInfoBlock
            errorAndFeedbackBlock
            if localModelsLoading {
                loadingPlaceholder
            } else {
                // 2. 已加载的模型（始终显示）
                Label("已加载", systemImage: "cpu.fill")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                if let id = loadedModelId,
                   let info = localAvailableModels.first(where: { $0.id == id }) {
                    LocalModelRow(
                        model: info,
                        isCached: true,
                        isSelected: false,
                        isDownloading: false,
                        downloadStatus: nil,
                        isDownloadDisabled: false,
                        isThisModelLoaded: true,
                        hasAnyModelLoaded: true,
                        isLoading: false,
                        isLoadDisabled: false,
                        onSelect: { },
                        onDownload: { },
                        onLoad: { },
                        onUnload: { Task { await onUnload() } }
                    )
                } else {
                    // 空状态友好提示
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "tray")
                            .font(.system(size: 16))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.6))
                        Text("暂无已加载的模型")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("从下方列表中选择模型并点击「加载」按钮")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // 3. 已下载的模型（始终显示所有已下载的，包括已加载的）
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
                                isThisModelLoaded: false,
                                hasAnyModelLoaded: loadedModelId != nil,
                                isLoading: loadingModelId == model.id,
                                isLoadDisabled: loadingModelId != nil,
                                onSelect: { },
                                onDownload: { },
                                onLoad: { Task { await onLoad(model.id) } },
                                onUnload: { }
                            )
                        }
                    }
                }
                // 4. 模型列表（展示所有模型）
                Label("模型列表", systemImage: "list.bullet")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                availableModelsList
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Label("本机信息", systemImage: "cpu")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
        let chip = Self.localChipName()
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        let diskGB = Self.localDiskTotalGB()
        let osVer = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(osVer.majorVersion).\(osVer.minorVersion).\(osVer.patchVersion)"
        let style = DesignTokens.Typography.caption2
        let color = DesignTokens.Color.semantic.textSecondary
        return HStack(spacing: 6) {
            Label(chip, systemImage: "cpu")
                .font(style)
                .foregroundColor(color)
            Text("·").font(style).foregroundColor(color)
            Label("内存 \(ramGB) GB", systemImage: "memorychip")
                .font(style)
                .foregroundColor(color)
            Text("·").font(style).foregroundColor(color)
            Label("磁盘 \(diskGB) GB", systemImage: "internaldrive")
                .font(style)
                .foregroundColor(color)
            Text("·").font(style).foregroundColor(color)
            Label(osString, systemImage: "desktopcomputer")
                .font(style)
                .foregroundColor(color)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
        )
    }

    private static func localChipName() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0) == 0 else {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        let name = String(cString: model).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "Apple processor" {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        return name
    }

    private static func localDiskTotalGB() -> Int {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64 else { return 0 }
        return Int(total / 1_000_000_000)
    }
}
