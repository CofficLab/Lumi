import SwiftUI

/// 思维导图主视图：文档工具条 + 画布 + 选中节点操作 + 空态。
public struct MindMapDesignerView: View {
    @ObservedObject private var store = MindMapStore.shared
    @State private var selectedNodeId: String?
    @State private var editingNodeId: String?
    @State private var scale: CGFloat = 1.0

    public init() {}

    public var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            if let map = store.selectedMap {
                MindMapCanvas(
                    map: map,
                    scope: store.selectedScope,
                    selectedNodeId: $selectedNodeId,
                    editingNodeId: $editingNodeId,
                    scale: $scale
                )
                .padding(.top, 4)

                VStack {
                    documentBar
                    Spacer()
                    if let id = selectedNodeId, let node = map.node(id: id) {
                        nodeActionBar(node: node, map: map)
                            .padding(.bottom, 16)
                    }
                }
            } else {
                emptyState
            }
        }
        .overlay(alignment: .top) {
            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: store.lastError)
        .animation(.easeInOut(duration: 0.15), value: selectedNodeId)
    }

    // MARK: - Document Bar

    private var documentBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $store.selectedScope) {
                ForEach(MindMapScope.allCases, id: \.self) { scope in
                    Text(scope.displayName()).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            .labelsHidden()

            Menu {
                ForEach(store.maps) { map in
                    Button(map.title) {
                        try? store.selectMindMap(id: map.id, scope: store.selectedScope)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text(store.selectedMap?.title ?? MindMapLocalization.string("Select Mind Map"))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)

            Spacer()

            Button {
                createMap()
            } label: {
                Label(MindMapLocalization.string("New"), systemImage: "plus")
            }

            if store.selectedMap != nil {
                Button(role: .destructive) {
                    if let id = store.selectedMap?.id { store.deleteMindMap(id: id, scope: store.selectedScope) }
                } label: {
                    Image(systemName: "trash")
                }
                .help(MindMapLocalization.string("Delete current mind map"))
            }

            Divider().frame(height: 18)

            Button { zoom(by: 0.1) } label: { Image(systemName: "plus.magnifyingglass") }
                .help(MindMapLocalization.string("Zoom In"))
            Button { zoom(by: -0.1) } label: { Image(systemName: "minus.magnifyingglass") }
                .help(MindMapLocalization.string("Zoom Out"))
            Button { scale = 1.0 } label: { Image(systemName: "1.magnifyingglass") }
                .help(MindMapLocalization.string("Reset Zoom"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Node Action Bar

    private func nodeActionBar(node: MindMapNode, map: MindMap) -> some View {
        let isRoot = node.parentId == nil
        let hasChildren = !map.children(of: node.id).isEmpty
        return HStack(spacing: 12) {
            Label(node.text, systemImage: isRoot ? "circle.fill" : "circle")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Divider().frame(height: 14)
            Button { addChild(to: node, map: map) } label: { Label(MindMapLocalization.string("Child"), systemImage: "plus.circle") }
            Button { addSibling(to: node, map: map) } label: { Label(MindMapLocalization.string("Sibling"), systemImage: "arrow.down.right.circle") }
                .disabled(isRoot)
            Button { toggleCollapse(node: node) } label: {
                Label(
                    node.collapsed ? MindMapLocalization.string("Expand") : MindMapLocalization.string("Collapse"),
                    systemImage: node.collapsed ? "chevron.right.circle" : "chevron.down.circle"
                )
            }
            .disabled(!hasChildren)
            Button(role: .destructive) { deleteSelected(node: node, map: map) } label: { Label(MindMapLocalization.string("Delete"), systemImage: "minus.circle") }
                .disabled(isRoot)
        }
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(MindMapLocalization.string("No Mind Map Yet"))
                .font(.title3.weight(.semibold))
            Text(MindMapLocalization.string("Ask the agent in chat to create one, e.g. \"create a mind map about Swift concurrency\", or click New."))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { createMap() } label: {
                Label(MindMapLocalization.string("Create Mind Map"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createMap() {
        let map = store.createMindMap(
            title: MindMapLocalization.string("New Mind Map"),
            rootText: MindMapLocalization.string("Central Topic"),
            direction: .bilateral,
            scope: store.selectedScope
        )
        selectedNodeId = map.root?.id
        editingNodeId = map.root?.id
    }

    private func addChild(to node: MindMapNode, map: MindMap) {
        do {
            let (_, created) = try store.addChildNodes(
                mapId: map.id, parentId: node.id,
                texts: [MindMapLocalization.string("New Node")], color: nil,
                scope: store.selectedScope
            )
            if let first = created.first {
                selectedNodeId = first.id
                editingNodeId = first.id
            }
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func addSibling(to node: MindMapNode, map: MindMap) {
        guard node.parentId != nil else { return }
        do {
            let (_, created) = try store.addSiblingNode(
                mapId: map.id, siblingId: node.id,
                text: MindMapLocalization.string("New Node"),
                scope: store.selectedScope
            )
            if let created {
                selectedNodeId = created.id
                editingNodeId = created.id
            }
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func toggleCollapse(node: MindMapNode) {
        guard let map = store.selectedMap else { return }
        do {
            _ = try store.updateNode(
                mapId: map.id, nodeId: node.id, scope: store.selectedScope,
                text: nil, note: nil, color: nil, collapsed: !node.collapsed
            )
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func deleteSelected(node: MindMapNode, map: MindMap) {
        do {
            _ = try store.deleteNode(mapId: map.id, nodeId: node.id, scope: store.selectedScope)
            selectedNodeId = nil
            editingNodeId = nil
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func zoom(by delta: CGFloat) {
        scale = max(0.3, min(3.0, scale + delta))
    }
}

// MARK: - Preview

#Preview {
    MindMapDesignerView()
        .frame(width: 800, height: 600)
}
