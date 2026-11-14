import Foundation
import LumiUI
import SwiftUI

/// 记忆设置视图 —— 左侧记忆列表 + 右侧详情面板。
@MainActor
struct MemorySettingsView: View {
    private let storage: MemoryFileStorage

    @LumiTheme private var theme

    @State private var globalItems: [MemoryItem] = []
    @State private var projectItems: [MemoryItem] = []
    @State private var selectedScope: MemoryScope = .global
    @State private var selectedTypeFilter: MemoryType? = nil
    @State private var selectedMemoryID: String? = nil
    @State private var searchQuery: String = ""
    /// 实际用于过滤的查询词。
    ///
    /// 与 `searchQuery` 之间有 200ms 防抖：每次按键都会让 body 重跑，
    /// 若直接用 `searchQuery` 过滤，每次按键都要全量过滤一遍记忆列表
    /// （见 issue #1304）。
    @State private var appliedSearchQuery: String = ""
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: MemoryItem? = nil

    init(storage: MemoryFileStorage) {
        self.storage = storage
    }

    private var filteredItems: [MemoryItem] {
        let items = selectedScope == .global ? globalItems : projectItems
        return MemoryListFilter.filter(
            items,
            type: selectedTypeFilter,
            query: appliedSearchQuery
        )
    }

    /// 当前选中的记忆条目。
    ///
    /// - Note: 直接从 `globalItems` / `projectItems` 查，而不是从 `filteredItems` 查，
    ///   避免再多触发一次全量过滤（见 issue #1304）。
    private var selectedMemory: MemoryItem? {
        guard let id = selectedMemoryID else { return nil }
        let items = selectedScope == .global ? globalItems : projectItems
        return items.first { $0.id == id }
    }

    var body: some View {
        PluginSettingsScaffold(
            title: "记忆管理",
            subtitle: "查看和管理 Agent 持久化的记忆条目",
            showHeader: false,
            scrollsContent: false
        ) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        AppButton("刷新", systemImage: "arrow.clockwise", size: .small) {
                            Task { await reloadItems() }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    // 主体内容贴边后，用一条顶部分隔线把头部行与主从容器分开。
                    AppDivider()

                    // 过滤结果只算一次并向下传递：原先 `filteredItems` 是纯计算属性，
                    // body 每次求值会读它 3~4 次，每次都全量过滤一遍记忆列表
                    // （见 issue #1304）。
                    let filtered = filteredItems

                    HStack(spacing: 0) {
                        sidebar(items: filtered)
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)

                        AppDivider(.vertical)

                        detailPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                // 共享 scaffold 给内容留了左右 24，这里把整列加宽 48 并左移 24，
                // 使主从容器正好贴到窗口左右边缘；标题行再自行补回 24 留白。
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .task {
            await reloadItems()
        }
        // 搜索防抖：`searchQuery` 变化时取消上一个待执行任务，
        // 只在用户停下输入 200ms 后才真正过滤（见 issue #1304）。
        .task(id: searchQuery) {
            guard !searchQuery.isEmpty else {
                appliedSearchQuery = ""
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            appliedSearchQuery = searchQuery
        }
        .alert(pluginLocalization.string("Delete Memory"), isPresented: $showDeleteConfirmation) {
            Button(pluginLocalization.string("Cancel"), role: .cancel) {
                itemToDelete = nil
            }
            Button(pluginLocalization.string("Delete"), role: .destructive) {
                if let item = itemToDelete {
                    Task { await deleteItem(item) }
                }
            }
        } message: {
            if let item = itemToDelete {
                Text(String(format: pluginLocalization.string("Delete memory \"%@\"? This action cannot be undone."), item.name))
            }
        }
    }

    // MARK: - Sidebar

    private func sidebar(items: [MemoryItem]) -> some View {
        VStack(spacing: 0) {
            scopeTabs
            typeFilter
            searchField
            AppDivider()

            if isLoading && items.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(pluginLocalization.string("Loading..."))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                AppEmptyState(
                    icon: "brain",
                    title: appliedSearchQuery.isEmpty ? "暂无记忆条目" : "没有匹配的记忆"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(items) { item in
                            memoryRow(item)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var scopeTabs: some View {
        AppTabBar(
            tabs: [
                AppTabBar.Tab(title: "全局", id: "global"),
                AppTabBar.Tab(title: "项目", id: "project"),
            ],
            selectedTab: Binding(
                get: { selectedScope.rawValue },
                set: { newValue in
                    guard let scope = MemoryScope(rawValue: newValue) else { return }
                    selectedScope = scope
                    selectedMemoryID = nil
                }
            )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var typeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                typeChip(label: "全部", type: nil)
                ForEach(MemoryType.allCases, id: \.self) { type in
                    typeChip(label: type.displayName, type: type)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func typeChip(label: String, type: MemoryType?) -> some View {
        let isSelected = selectedTypeFilter == type
        return Button {
            selectedTypeFilter = type
        } label: {
            Text(label)
                .font(.appMicro)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    isSelected ? theme.primary.opacity(0.15) : theme.elevatedSurface,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.appCaption)
                .foregroundStyle(theme.textTertiary)
            TextField(pluginLocalization.string("Search memories..."), text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.appCaption)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.appCaption)
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.elevatedSurface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private func memoryRow(_ item: MemoryItem) -> some View {
        let isSelected = item.id == selectedMemoryID
        return Button {
            selectedMemoryID = item.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: iconForType(item.type))
                        .font(.appMicro)
                        .foregroundStyle(colorForType(item.type))
                    Text(item.name)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(item.type.displayName)
                        .font(.appMonoMicro)
                        .foregroundStyle(colorForType(item.type))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(colorForType(item.type).opacity(0.1), in: Capsule())
                }
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? theme.primary.opacity(0.1) : .clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let memory = selectedMemory {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: iconForType(memory.type))
                            .font(.appBody)
                            .foregroundStyle(colorForType(memory.type))
                        Text(memory.name)
                            .font(.appSectionTitle)
                            .foregroundStyle(theme.textPrimary)
                        Spacer(minLength: 0)
                        Button {
                            itemToDelete = memory
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.appCaption)
                                .foregroundStyle(theme.error)
                                .padding(6)
                                .background(theme.error.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help(pluginLocalization.string("Delete Memory"))
                    }

                    if !memory.description.isEmpty {
                        Text(memory.description)
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        metadataTag(icon: "tag", text: memory.type.displayName, color: colorForType(memory.type))
                        metadataTag(icon: "calendar", text: formattedDate(memory.createdAt), color: theme.textTertiary)
                        metadataTag(icon: "clock", text: formattedDate(memory.updatedAt), color: theme.textTertiary)
                        metadataTag(icon: "number", text: "ID: \(memory.id)", color: theme.textTertiary)
                    }
                }
                .padding(22)

                AppDivider()

                // Content
                ScrollView {
                    Text(memory.content)
                        .font(.appCaption)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(22)
                }
            }
        } else {
            VStack(spacing: 12) {
                AppEmptyState(
                    icon: "brain",
                    title: "选择一条记忆查看详情"
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metadataTag(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.appMicro)
            Text(text)
                .font(.appMicro)
        }
        .foregroundStyle(color)
    }

    // MARK: - Helpers

    private func iconForType(_ type: MemoryType) -> String {
        switch type {
        case .user: return "person"
        case .feedback: return "bubble.left"
        case .project: return "folder"
        case .reference: return "book"
        }
    }

    private func colorForType(_ type: MemoryType) -> Color {
        switch type {
        case .user: return .blue
        case .feedback: return .orange
        case .project: return .green
        case .reference: return .purple
        }
    }

    /// 相对时间格式化器。
    ///
    /// `RelativeDateTimeFormatter` 的初始化不便宜，详情面板每次求值都会用到，
    /// 因此复用同一个实例。
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Actions

    private func reloadItems() async {
        isLoading = true
        defer { isLoading = false }
        let global = await storage.list(scope: .global, projectPath: nil)
        let project = await storage.list(scope: .project, projectPath: nil)
        globalItems = global
        projectItems = project
    }

    private func deleteItem(_ item: MemoryItem) async {
        try? await storage.delete(id: item.id, scope: selectedScope, projectPath: nil)
        if selectedMemoryID == item.id {
            selectedMemoryID = nil
        }
        await reloadItems()
    }
}
