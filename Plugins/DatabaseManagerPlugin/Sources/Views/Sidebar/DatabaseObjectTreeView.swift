import LumiKernel
import LumiUI
import SwiftUI

/// 侧边栏对象树：按对象分类（Tables / Views / 例程）分组展示当前连接的可浏览对象。
///
/// 数据来自 ``DatabaseViewModel/schemaCache``，由 ``DatabaseViewModel/refreshSidebarObjects()``
/// 在连接成功后预加载。MySQL/PostgreSQL 由此获得与 SQLite 一致的表浏览体验。
///
/// 树结构：分类节点（可展开）→ 对象叶子节点。顶部 ``AppSearchBar`` 按名称过滤。
struct DatabaseObjectTreeView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @ObservedObject var viewModel: DatabaseViewModel

    /// 点击切换数据/连接列表的回调（与既有侧边栏头部一致）。
    var onToggleMode: () -> Void

    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            DatabaseSidebarHeaderBar(
                title: headerTitle,
                systemImage: "list.bullet.indent",
                onLoad: { Task { await viewModel.refreshSidebarObjects() } },
                onToggleMode: onToggleMode,
                toggleMode: viewModel.sidebarMode
            )

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField(LumiPluginLocalization.string("Filter objects", bundle: .module), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.appCaption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.appSubtleBorder, in: .rect(cornerRadius: 6))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            if groupedNodes.isEmpty {
                SidebarEmptyView(
                    systemImage: "tablecells",
                    title: LumiPluginLocalization.string("No objects", bundle: .module),
                    description: LumiPluginLocalization.string("Click Reload to refresh the object list.", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        OutlineGroup(groupedNodes, id: \.id, children: \.children) { node in
                            if node.isLeaf {
                                leafRow(node)
                            } else {
                                groupRow(node)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Derived

    private var headerTitle: String {
        viewModel.selectedConfig?.name ?? LumiPluginLocalization.string("Database", bundle: .module)
    }

    /// 当前选中对象名，用于高亮行。
    private var selectedObjectName: String? {
        viewModel.selectedSQLiteTable
    }

    /// 按对象分类分组成树节点，应用搜索过滤；空分类隐藏。
    private var groupedNodes: [TreeNode] {
        guard let config = viewModel.selectedConfig else { return [] }
        let predicate = makeSearchPredicate()
        var nodes: [TreeNode] = []
        for kind in config.type.sidebarObjectKinds {
            let key = SchemaCacheService.CacheKey(
                configId: config.id,
                kind: kind,
                database: config.type == .sqlite ? nil : config.database,
                schema: nil
            )
            let objects = (viewModel.schemaCache.objectsByKey[key] ?? []).filter(predicate)
            if objects.isEmpty { continue }
            let children = objects.map { object in
                TreeNode(
                    id: object.id,
                    kind: kind,
                    object: object,
                    title: object.name,
                    systemImage: kind.systemImage,
                    children: nil
                )
            }
            nodes.append(TreeNode(
                id: "kind-\(kind.rawValue)",
                kind: kind,
                object: nil,
                title: "\(kind.sectionKey) (\(objects.count))",
                systemImage: "folder",
                children: children
            ))
        }
        return nodes
    }

    private func makeSearchPredicate() -> (DatabaseObject) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return { _ in true } }
        return { $0.name.lowercased().contains(trimmed) }
    }

    // MARK: - Rows

    @ViewBuilder
    private func groupRow(_ node: TreeNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: node.systemImage)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(node.title)
                .font(.appMicroEmphasized)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func leafRow(_ node: TreeNode) -> some View {
        let isSelected = selectedObjectName == node.object?.name
        AppSidebarRow(
            title: node.title,
            systemImage: node.systemImage,
            leadingColor: nil,
            isSelected: isSelected
        ) {
            guard let object = node.object else { return }
            Task { await viewModel.openObject(object) }
        }
        .contextMenu {
            if let object = node.object {
                Button {
                    Task { await viewModel.openObject(object) }
                } label: {
                    Label(LumiPluginLocalization.string("Open", bundle: .module), systemImage: "arrow.right.circle")
                }
            }
        }
    }
}

// MARK: - Tree node model

private struct TreeNode: Identifiable, Hashable {
    let id: String
    let kind: DatabaseObjectKind?
    let object: DatabaseObject?
    let title: String
    let systemImage: String
    let children: [TreeNode]?

    var isLeaf: Bool { children == nil }
}
