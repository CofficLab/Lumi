import AppKit
import LumiUI
import SwiftUI

private typealias L = MindMapLocalization

/// 思维导图主视图：项目工具栏、画布和底部导出工具栏。
public struct MindMapDesignerView: View {
    @ObservedObject private var store: MindMapStore
    @State private var selectedNodeId: String?
    @State private var editingNodeId: String?
    @State private var scale: CGFloat = 1.0
    @State private var isExporting = false
    private let onMapAvailabilityChanged: ((Bool) -> Void)?

    init(
        store: MindMapStore,
        onMapAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.store = store
        self.onMapAvailabilityChanged = onMapAvailabilityChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.projectStorageDirectory == nil || store.projectMaps.isEmpty {
                emptyToolbar
                MindMapOnboardingView(isProjectOpen: store.projectStorageDirectory != nil)
            } else if let map = store.selectedMap {
                topToolbar(for: map)

                ZStack(alignment: .bottom) {
                    MindMapCanvas(
                        map: map,
                        scope: .project,
                        selectedNodeId: $selectedNodeId,
                        editingNodeId: $editingNodeId,
                        scale: $scale,
                        store: store
                    )
                    .padding(.top, 4)

                    if let id = selectedNodeId, let node = map.node(id: id) {
                        nodeActionBar(node: node, map: map)
                            .padding(.bottom, DesignTokens.Spacing.md)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomToolbar(for: map)
            } else {
                MindMapTaskSelectionView(
                    message: L.string(
                        "Select a mind map from the left, or ask the Agent to create one."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            if let error = store.lastError {
                Text(error)
                    .font(.appCaption)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(themeErrorBackground, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .transition(.opacity)
            }
        }
        .onAppear {
            notifyMapAvailability()
        }
        .onChange(of: store.projectMaps.count) { _, _ in
            notifyMapAvailability()
        }
    }

    private var themeErrorBackground: Color {
        Color.red.opacity(0.85)
    }

    private var emptyToolbar: some View {
        AppToolbarContainer {
            HStack {
                AppToolbarTitleLabel(icon: "brain.head.profile", title: L.string("Mind Maps"))
                Spacer(minLength: 0)
                AppIconButton(systemImage: "arrow.clockwise", action: store.reload)
                    .accessibilityLabel(L.string("Refresh"))
                    .help(L.string("Refresh"))
            }
        }
        .borderBottom()
    }

    private func topToolbar(for map: MindMap) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppToolbarTitleLabel(icon: "brain.head.profile", title: map.title)
                AppTag(L.string("In Project"), systemImage: "folder", style: .subtle)

                if let projectName = store.currentProjectPath?.split(separator: "/").last {
                    Text(projectName)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                AppIconButton(systemImage: "trash", action: { store.deleteMindMap(id: map.id, scope: .project) })
                    .accessibilityLabel(L.string("Delete current mind map"))
                    .help(L.string("Delete current mind map"))
            }
        }
        .borderBottom()
    }

    private func bottomToolbar(for map: MindMap) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Spacer(minLength: 0)

                AppButton(
                    L.string("Export Markdown"),
                    systemImage: "arrow.down.doc",
                    style: .secondary,
                    size: .small
                ) {
                    export(map, format: .markdown)
                }
                .disabled(isExporting)

                AppButton(
                    L.string("Export JSON"),
                    systemImage: "curlybraces",
                    style: .secondary,
                    size: .small
                ) {
                    export(map, format: .json)
                }
                .disabled(isExporting)

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
            }
        }
        .borderTop()
    }

    private func nodeActionBar(node: MindMapNode, map: MindMap) -> some View {
        let isRoot = node.parentId == nil
        let hasChildren = !map.children(of: node.id).isEmpty

        return HStack(spacing: DesignTokens.Spacing.sm) {
            Label(node.text, systemImage: isRoot ? "circle.fill" : "circle")
                .font(.appCaption)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            AppIconButton(systemImage: "plus.circle", action: { addChild(to: node, map: map) })
                .accessibilityLabel(L.string("Child"))
                .help(L.string("Child"))
            AppIconButton(systemImage: "arrow.down.right.circle", action: { addSibling(to: node, map: map) })
                .disabled(isRoot)
                .accessibilityLabel(L.string("Sibling"))
                .help(L.string("Sibling"))
            AppIconButton(
                systemImage: node.collapsed ? "chevron.right.circle" : "chevron.down.circle",
                action: { toggleCollapse(node: node) }
            )
            .disabled(!hasChildren)
            .accessibilityLabel(node.collapsed ? L.string("Expand") : L.string("Collapse"))
            .help(node.collapsed ? L.string("Expand") : L.string("Collapse"))
            AppIconButton(systemImage: "minus.circle", action: { deleteSelected(node: node, map: map) })
                .disabled(isRoot)
                .accessibilityLabel(L.string("Delete"))
                .help(L.string("Delete"))
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }

    private func addChild(to node: MindMapNode, map: MindMap) {
        do {
            _ = try store.addChildNodes(
                mapId: map.id,
                parentId: node.id,
                texts: [L.string("New Branch")],
                color: nil,
                scope: .project
            )
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func addSibling(to node: MindMapNode, map: MindMap) {
        do {
            _ = try store.addSiblingNode(
                mapId: map.id,
                siblingId: node.id,
                text: L.string("New Branch"),
                scope: .project
            )
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func toggleCollapse(node: MindMapNode) {
        do {
            _ = try store.updateNode(
                mapId: store.selectedMap?.id ?? "",
                nodeId: node.id,
                scope: .project,
                text: nil,
                note: nil,
                color: nil,
                collapsed: !node.collapsed
            )
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private func deleteSelected(node: MindMapNode, map: MindMap) {
        do {
            _ = try store.deleteNode(mapId: map.id, nodeId: node.id, scope: .project)
            selectedNodeId = nil
        } catch {
            store.setError(error.localizedDescription)
        }
    }

    private enum ExportFormat {
        case markdown
        case json

        var fileExtension: String {
            switch self {
            case .markdown: "md"
            case .json: "json"
            }
        }
    }

    private func export(_ map: MindMap, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(map.title).\(format.fileExtension)"
        panel.prompt = L.string("Export")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true

        do {
            let data: Data
            switch format {
            case .markdown:
                data = MindMapMarkdownCodec.encode(map).data(using: .utf8) ?? Data()
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                data = try encoder.encode(map)
            }
            try data.write(to: url, options: .atomic)
            isExporting = false
        } catch {
            isExporting = false
            store.setError(error.localizedDescription)
        }
    }

    private func notifyMapAvailability() {
        onMapAvailabilityChanged?(!store.projectMaps.isEmpty)
    }
}
