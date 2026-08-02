import SwiftUI
import AppKit
import LumiUI
import LumiKernel

/// 工具管理器设置视图
///
/// 设计要点:
/// - 视图持有 `kernel` 引用,在每次打开时实时从内核拉取工具列表
/// - 从 ToolCallRecordStore 读取调用统计(调用次数、失败次数、平均耗时)
/// - 顶部左侧 AppTabBar：Tools(原界面) / Execution Log(双栏日志，跟 NetworkManager 的 HTTP 日志对齐)
/// - 右上角有「Open Data Directory」按钮可打开存储目录
public struct ToolManagerSettingsView: View {
    let kernel: LumiKernel
    let toolCallRecordStore: ToolCallRecordStore?

    @State private var selectedTabID: ToolSettingsTab = .tools

    @State private var groups: [(pluginID: String, tools: [any LumiAgentTool])] = []
    @State private var pluginDisplayNames: [String: String] = [:]
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var visibleToolLimit = 100
    @State private var toolStats: [ToolStats] = []
    @State private var isLoadingStats = false

    private let toolPageSize = 100

    enum ToolSettingsTab: String, Identifiable {
        case tools
        case executionLog

        var id: String { rawValue }

        var title: String {
            switch self {
            case .tools: LumiPluginLocalization.string("Tools", bundle: .module)
            case .executionLog: LumiPluginLocalization.string("Execution Log", bundle: .module)
            }
        }

        var icon: String {
            switch self {
            case .tools: "wrench.and.screwdriver"
            case .executionLog: "list.bullet.rectangle.portrait"
            }
        }
    }

    public init(
        kernel: LumiKernel,
        toolCallRecordStore: ToolCallRecordStore? = nil
    ) {
        self.kernel = kernel
        self.toolCallRecordStore = toolCallRecordStore
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 12) {
                tabBar
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await reload()
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        AppTabBar(
            tabs: availableTabs,
            selectedTab: Binding(
                get: { selectedTabID.rawValue },
                set: { newValue in
                    if let next = ToolSettingsTab(rawValue: newValue) {
                        selectedTabID = next
                    }
                }
            )
        )
    }

    private var availableTabs: [AppTabBar.Tab] {
        var tabs: [AppTabBar.Tab] = [
            AppTabBar.Tab(
                title: ToolSettingsTab.tools.title,
                icon: ToolSettingsTab.tools.icon,
                id: ToolSettingsTab.tools.rawValue
            )
        ]
        if toolCallRecordStore != nil {
            tabs.append(
                AppTabBar.Tab(
                    title: ToolSettingsTab.executionLog.title,
                    icon: ToolSettingsTab.executionLog.icon,
                    id: ToolSettingsTab.executionLog.rawValue
                )
            )
        }
        return tabs
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTabID {
        case .tools:
            toolsContent
        case .executionLog:
            if let toolCallRecordStore {
                ToolCallLogSettingsView(store: toolCallRecordStore)
            } else {
                AppEmptyState(
                    icon: "list.bullet.rectangle.portrait",
                    title: LumiPluginLocalization.string("Execution Log unavailable", bundle: .module),
                    description: LumiPluginLocalization.string("Lumi storage is not configured, so tool call records cannot be persisted.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var toolsContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolsHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 工具调用统计
                    if !toolStats.isEmpty {
                        toolStatsSection
                    }

                    // 可用工具列表
                    if isLoading {
                        ProgressView(LumiPluginLocalization.string("Loading...", bundle: .module))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if groups.isEmpty {
                        AppEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: LumiPluginLocalization.string("No Tools Registered", bundle: .module),
                            description: LumiPluginLocalization.string("No tools are currently registered in the kernel. Enable plugins to make tools available to the LLM.", bundle: .module)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ForEach(displayedGroups, id: \.pluginID) { group in
                            pluginSection(pluginID: group.pluginID, tools: group.tools)
                        }

                        if visibleToolLimit < totalToolCount {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .onAppear {
                                    visibleToolLimit += toolPageSize
                                }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var toolsHeader: some View {
        HStack(spacing: 10) {
            Label(totalToolLabel, systemImage: "wrench.and.screwdriver")
            Spacer()
            AppButton(
                LumiPluginLocalization.string("Open Data Directory", bundle: .module),
                systemImage: "folder",
                size: .small
            ) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Sections

    private var toolStatsSection: some View {
        AppSettingSection(title: LumiPluginLocalization.string("Usage Statistics", bundle: .module)) {
            VStack(spacing: 0) {
                ForEach(toolStats) { stat in
                    ToolStatsRowView(stats: stat)
                    if stat.id != toolStats.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var totalToolCount: Int {
        groups.reduce(0) { $0 + $1.tools.count }
    }

    private var totalToolLabel: String {
        if isLoading {
            return LumiPluginLocalization.string("Loading...", bundle: .module)
        }
        return "\(totalToolCount) " + LumiPluginLocalization.string("tools", bundle: .module)
    }

    private var displayedGroups: [(pluginID: String, tools: [any LumiAgentTool])] {
        var remaining = visibleToolLimit
        var result: [(pluginID: String, tools: [any LumiAgentTool])] = []
        result.reserveCapacity(groups.count)

        for group in groups {
            guard remaining > 0 else { break }
            let visibleTools = Array(group.tools.prefix(remaining))
            guard !visibleTools.isEmpty else { continue }
            result.append((pluginID: group.pluginID, tools: visibleTools))
            remaining -= visibleTools.count
        }
        return result
    }

    private func pluginSection(pluginID: String, tools: [any LumiAgentTool]) -> some View {
        let displayName = pluginDisplayNames[pluginID] ?? pluginID

        return AppSettingSection(title: displayName, titleAlignment: .leading) {
            LazyVStack(spacing: 0) {
                ForEach(tools, id: \.name) { tool in
                    ToolManagerToolRowView(tool: tool)
                }
            }
        }
    }

    // MARK: - Data Loading

    /// 实时从内核读取工具分组、插件显示名和调用统计。
    @MainActor
    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        isLoadingStats = true
        defer {
            isReloading = false
            isLoading = false
        }

        // 让 SwiftUI 先提交 loading 状态，再读取数据
        await Task.yield()

        // 读取工具列表
        groups = kernel.toolManager?.agentToolsGroupedByPlugin() ?? []
        var names: [String: String] = [:]
        for plugin in kernel.pluginManager.allPlugins {
            names[plugin.id] = plugin.name
        }
        pluginDisplayNames = names
        visibleToolLimit = toolPageSize

        // 读取调用统计
        if let service = kernel.toolManager as? ToolManagerService {
            toolStats = await service.recordStore?.fetchToolStats() ?? []
        }
        isLoadingStats = false
    }

    // MARK: - Actions

    private func openDataDirectory() {
        guard let storage = kernel.storage else { return }
        let url = storage.pluginDataDirectory(for: "ToolManager")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - ToolStatsRowView

/// 展示单个工具调用统计的行视图。
struct ToolStatsRowView: View {
    let stats: ToolStats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(stats.toolDisplayName)
                    .font(.appBody)
                    .lineLimit(1)

                Text(stats.toolName)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                // 调用次数
                statBadge(
                    value: "\(stats.totalCount)",
                    label: "calls",
                    color: .blue
                )

                // 失败次数
                if stats.errorCount > 0 {
                    statBadge(
                        value: "\(stats.errorCount)",
                        label: "errors",
                        color: .red
                    )
                }

                // 平均耗时
                statBadge(
                    value: formatDuration(stats.averageDuration),
                    label: "avg",
                    color: .secondary
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            return String(format: "%.0fm", seconds / 60)
        }
    }
}
