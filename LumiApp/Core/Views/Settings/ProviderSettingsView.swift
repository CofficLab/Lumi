import SwiftUI
import AppKit
import MagicKit
import Darwin

/// 供应商设置视图 - 配置 LLM 供应商的 API 密钥和模型选择
struct ProviderSettingsView: View, SuperLog {
    // MARK: - SuperLog

    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - State

    /// 当前选中的供应商 ID
    @State private var selectedProviderId: String = "anthropic"
    
    /// API Key 输入
    @State private var apiKey: String = ""
    
    /// 选中的模型
    @State private var selectedModel: String = ""

    /// 当前选中的本地供应商实例（用于展示本地模型列表、下载、加载）
    @State private var localProvider: (any SuperLocalLLMProvider)?
    /// 本地可用模型列表
    @State private var localAvailableModels: [LocalModelInfo] = []
    /// 已缓存模型 ID
    @State private var localCachedIds: Set<String> = []
    /// 本地模型加载中
    @State private var localModelsLoading = false
    /// 下载/加载错误信息
    @State private var localActionError: String?
    /// 当前正在下载的模型 ID（用于显示该行进度）
    @State private var downloadingModelId: String?
    /// 轮询得到的下载状态（用于 UI 实时更新）
    @State private var localDownloadStatus: LocalDownloadStatus = .idle
    /// 当前选中的本地模型系列 Tab（如「Qwen 系列」）
    @State private var selectedSeriesName: String = ""

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    @EnvironmentObject private var registry: ProviderRegistry

    // MARK: - Computed Properties

    /// 当前选中的供应商信息
    private var selectedProvider: ProviderInfo? {
        registry.allProviders().first(where: { $0.id == selectedProviderId })
    }

    /// 当前供应商类型
    private var selectedProviderType: (any SuperLLMProvider.Type)? {
        registry.providerType(forId: selectedProviderId)
    }

    /// 本地模型按系列分组，顺序由协议数据决定（按系列名排序，无系列归为「其他」）
    private var localModelsBySeries: [LocalModelsSection] {
        let fallbackSeries = "其他"
        let grouped = Dictionary(grouping: localAvailableModels) { $0.series ?? fallbackSeries }
        return grouped.keys.sorted().map { LocalModelsSection(seriesName: $0, models: grouped[$0] ?? []) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                // 供应商选择器
                providerSelector

                // 供应商信息卡片
                providerInfoCard

                // API Key 配置（仅远程供应商需要，本地模型无需 API Key）
                if localProvider == nil {
                    apiKeySection
                }

                // 模型：本地供应商只显示一个区块（列表+下载/加载），远程只显示可用模型列表
                if localProvider != nil {
                    localModelSection
                } else {
                    modelSection
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .onAppear(perform: onAppear)
        .onChange(of: selectedProviderId) { _, _ in
            loadSettings()
            updateLocalProvider()
        }
        .onChange(of: apiKey) { _, _ in
            saveApiKey()
        }
    }
}

// MARK: - View

extension ProviderSettingsView {
    /// 供应商选择器 - 显示所有可用的 LLM 供应商按钮
    private var providerSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("LLM 供应商")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(registry.allProviders()) { provider in
                    ProviderButton(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedProviderId = provider.id
                        }
                    }
                }
            }
        }
    }

    /// 供应商信息卡片 - 显示当前选中供应商的图标、名称和描述
    private var providerInfoCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: selectedProvider?.iconName ?? "dot.square")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignTokens.Color.semantic.primary, DesignTokens.Color.semantic.primarySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Color.semantic.primary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedProvider?.displayName ?? "未知供应商")
                    .font(DesignTokens.Typography.callout)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(selectedProvider?.description ?? "")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    /// API Key 配置区域 - 提供文本输入框供用户输入 API 密钥
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("API 密钥")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            TextField("输入 API Key", text: $apiKey)
                .textFieldStyle(.plain)
                .textContentType(.password)
                .font(DesignTokens.Typography.body)
                .padding(DesignTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .fill(DesignTokens.Material.glass)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }

    /// 模型选择区域 - 显示当前供应商支持的所有可用模型
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("可用模型")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                let models: [String] = {
                    guard let provider = selectedProvider else { return [] }
                    return provider.availableModels
                }()

                ForEach(models, id: \.self) { model in
                    ModelRow(
                        model: model,
                        isDefault: selectedModel == model,
                        isSelected: selectedModel == model
                    ) {
                        selectedModel = model
                        saveModel()
                    }
                }
            }
        }
    }

    /// 本地模型区域 - 选中本地供应商时作为唯一的模型区块：列表、已缓存、下载、加载
    @ViewBuilder
    private var localModelSection: some View {
        if localProvider != nil {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    Text("模型")
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Spacer()
                    Button("打开下载目录") {
                        guard let local = localProvider else { return }
                        NSWorkspace.shared.open(local.getCacheDirectoryURL())
                    }
                    .buttonStyle(.borderless)
                }

                // 本机信息：便于用户对比模型所需配置
                localMachineInfoBlock

                if localActionError != nil {
                    Text(localActionError!)
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.error)
                }

                if localModelsLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // 系列 Tab 横向展示
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
                        // 当前系列下的模型列表
                        if let section = localModelsBySeries.first(where: { $0.seriesName == selectedSeriesName }) ?? localModelsBySeries.first {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                ForEach(section.models) { model in
                                    LocalModelRow(
                                        model: model,
                                        isCached: localCachedIds.contains(model.id),
                                        isSelected: selectedModel == model.id,
                                        isDownloading: downloadingModelId == model.id,
                                        downloadStatus: downloadingModelId == model.id ? localDownloadStatus : nil,
                                        isDownloadDisabled: downloadingModelId != nil,
                                        onSelect: {
                                            selectedModel = model.id
                                            saveModel()
                                        },
                                        onDownload: {
                                            Task { await downloadLocalModel(id: model.id) }
                                        },
                                        onLoad: {
                                            Task { await loadLocalModel(id: model.id) }
                                        },
                                        onUnload: {
                                            Task { await unloadLocalModel() }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: localAvailableModels.count) { _, count in
                if count > 0,
                   selectedSeriesName.isEmpty || !localModelsBySeries.contains(where: { $0.seriesName == selectedSeriesName }) {
                    selectedSeriesName = localModelsBySeries.first?.seriesName ?? ""
                }
            }
            .task(id: selectedProviderId) {
                await refreshLocalModels()
                if !localAvailableModels.isEmpty {
                    selectedSeriesName = localModelsBySeries.first?.seriesName ?? ""
                }
            }
            .task(id: localProvider != nil ? "poll" : "nop") {
                guard localProvider != nil else { return }
                while !Task.isCancelled {
                    localDownloadStatus = localProvider?.getDownloadStatus() ?? .idle
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }
    }

    /// 本机信息区块：芯片、电脑内存、磁盘、系统版本，单行紧凑
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

    /// 本机芯片名称（sysctl machdep.cpu.brand_string；Apple Silicon 若为空则显示 "Apple Silicon"）
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

    /// 本机系统盘总容量（GB，按十进制 1 GB = 10⁹ 字节，与厂商/Finder 标称一致）
    private static func localDiskTotalGB() -> Int {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64 else { return 0 }
        return Int(total / 1_000_000_000)
    }
}

// MARK: - Action

extension ProviderSettingsView {
    /// 加载当前供应商的设置信息（API Key 和选中的模型）
    private func loadSettings() {
        guard let providerType = selectedProviderType else { return }

        apiKey = AppSettingsStore.shared.string(forKey: providerType.apiKeyStorageKey) ?? ""
        selectedModel = AppSettingsStore.shared.string(forKey: providerType.modelStorageKey)
            ?? providerType.defaultModel
    }

    /// 保存 API Key 到 UserDefaults
    private func saveApiKey() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(apiKey, forKey: providerType.apiKeyStorageKey)
    }

    /// 保存选中的模型到 UserDefaults
    private func saveModel() {
        guard let providerType = selectedProviderType else { return }
        AppSettingsStore.shared.set(selectedModel, forKey: providerType.modelStorageKey)
    }

    /// 根据当前选中的供应商 ID 更新本地供应商引用
    private func updateLocalProvider() {
        localProvider = registry.createProvider(id: selectedProviderId) as? any SuperLocalLLMProvider
        localActionError = nil
    }

    /// 刷新本地模型列表与已缓存集合
    private func refreshLocalModels() async {
        guard let local = localProvider else {
            localAvailableModels = []
            localCachedIds = []
            return
        }
        localModelsLoading = true
        localActionError = nil
        defer { localModelsLoading = false }
        do {
            localAvailableModels = await local.getAvailableModels()
            localCachedIds = await local.getCachedModels()
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func downloadLocalModel(id: String) async {
        guard let local = localProvider else { return }
        localActionError = nil
        downloadingModelId = id
        defer { downloadingModelId = nil }
        do {
            try await local.downloadModel(id: id)
            localCachedIds = await local.getCachedModels()
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func loadLocalModel(id: String) async {
        guard let local = localProvider else { return }
        localActionError = nil
        do {
            try await local.loadModel(id: id)
        } catch {
            localActionError = error.localizedDescription
        }
    }

    private func unloadLocalModel() async {
        guard let local = localProvider else { return }
        localActionError = nil
        await local.unloadModel()
    }
}

// MARK: - Event Handler

extension ProviderSettingsView {
    /// 视图出现时的事件处理 - 加载供应商设置
    func onAppear() {
        loadSettings()
        updateLocalProvider()
    }
}

// MARK: - Provider Button

/// 供应商选择按钮组件
private struct ProviderButton: View {
    let provider: ProviderInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(provider.displayName)
                    .font(DesignTokens.Typography.caption1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
            )
            .foregroundColor(isSelected ? .white : DesignTokens.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Model Row

/// 模型选择行组件 - 支持 hover 效果和选中/默认状态高亮
private struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(model)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                if isDefault {
                    Text("默认")
                        .font(DesignTokens.Typography.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignTokens.Color.semantic.primary.opacity(0.15))
                        )
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.08) : isDefault ? DesignTokens.Color.semantic.primary.opacity(0.04) : isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .stroke(
                                isSelected ? DesignTokens.Color.semantic.primary : isHovered ? DesignTokens.Color.semantic.primary.opacity(0.5) : isDefault ? DesignTokens.Color.semantic.primary.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Local Model Row

/// 本地模型行：显示名称、大小、已缓存、下载进度/加载按钮
private struct LocalModelRow: View {
    let model: LocalModelInfo
    let isCached: Bool
    let isSelected: Bool
    let isDownloading: Bool
    let downloadStatus: LocalDownloadStatus?
    let isDownloadDisabled: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onUnload: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态图标
            Group {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if isCached {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(DesignTokens.Color.semantic.primary.opacity(0.8))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(DesignTokens.Color.semantic.textSecondary)
                }
            }
            .frame(width: 20, height: 20)

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    // 体积、内存要求、下载状态
                    HStack(spacing: 6) {
                        Text("体积 \(model.size)")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("·")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("电脑内存 ≥ \(model.minRAM) GB")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        if isDownloading, case .downloading(let fraction) = downloadStatus {
                            Text("· \(Int(fraction * 100))%")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.primary)
                                .monospacedDigit()
                        } else if isCached {
                            Text("· 已缓存")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                    if !model.description.isEmpty {
                        Text(model.description)
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .lineLimit(2)
                    }
                    // 能力标签：工具调用、视觉
                    if model.supportsTools || model.supportsVision {
                        HStack(spacing: 6) {
                            if model.supportsTools {
                                capabilityTag("工具调用")
                            }
                            if model.supportsVision {
                                capabilityTag("视觉")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isDownloading {
                ProgressView(value: downloadProgressFraction)
                    .frame(width: 60)
            } else if !isCached {
                Button("下载", action: onDownload)
                    .font(DesignTokens.Typography.caption1)
                    .disabled(isDownloadDisabled)
            } else {
                Button("加载", action: onLoad)
                    .font(DesignTokens.Typography.caption1)
                Button("卸载", action: onUnload)
                    .font(DesignTokens.Typography.caption1)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.08) : Color.white.opacity(0.05))
        )
    }

    private var downloadProgressFraction: Double {
        guard case .downloading(let fraction) = downloadStatus else { return 0 }
        return fraction
    }

    private func capabilityTag(_ title: String) -> some View {
        Text(title)
            .font(DesignTokens.Typography.caption2)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.15))
            )
    }
}

// MARK: - Series Tab Button

/// 系列 Tab 按钮，横向排列
private struct SeriesTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? DesignTokens.Color.semantic.primary : Color.white.opacity(0.05))
                )
                .foregroundColor(isSelected ? .white : DesignTokens.Color.semantic.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Local Models Section

/// 本地模型按系列分组，用于设置页展示
private struct LocalModelsSection: Identifiable {
    let seriesName: String
    let models: [LocalModelInfo]
    var id: String { seriesName }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 500)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ProviderSettingsView()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
