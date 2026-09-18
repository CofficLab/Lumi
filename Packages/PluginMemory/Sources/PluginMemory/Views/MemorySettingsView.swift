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
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: MemoryItem? = nil

    init(storage: MemoryFileStorage) {
        self.storage = storage
    }

    private var filteredItems: [MemoryItem] {
        let items = selectedScope == .global ? globalItems : projectItems
        return items.filter { item in
            let matchesType = selectedTypeFilter == nil || item.type == selectedTypeFilter
            let matchesSearch = searchQuery.isEmpty
                || item.name.localizedCaseInsensitiveContains(searchQuery)
                || item.description.localizedCaseInsensitiveContains(searchQuery)
                || item.id.localizedCaseInsensitiveContains(searchQuery)
            return matchesType && matchesSearch
        }
    }

    private var selectedMemory: MemoryItem? {
        guard let id = selectedMemoryID else { return nil }
        return filteredItems.first { $0.id == id }
    }

    var body: some View {
        PluginSettingsScaffold(
            title: "记忆管理",
            subtitle: "查看和管理 Agent 持久化的记忆条目",
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    AppButton("刷新", systemImage: "arrow.clockwise", size: .small) {
                        Task { await reloadItems() }
                    }
                }

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 320)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await reloadItems()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                itemToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let item = itemToDelete {
                    Task { await deleteItem(item) }
                }
            }
        } message: {
            if let item = itemToDelete {
                Text("确定要删除记忆「\(item.name)」吗？此操作不可撤销。")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            scopeTabs
            typeFilter
            searchField
            AppDivider()

            if isLoading && filteredItems.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载中...")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                AppEmptyState(
                    icon: "brain",
                    title: searchQuery.isEmpty ? "暂无记忆条目" : "没有匹配的记忆"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
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
            TextField("搜索记忆...", text: $searchQuery)
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
                        .font(.appMicroMonospaced)
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
                            .font(.appTitle3Emphasized)
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
                        .help("删除记忆")
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
                .padding(16)

                AppDivider()

                // Content
                ScrollView {
                    Text(memory.content)
                        .font(.appCaption)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
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

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
