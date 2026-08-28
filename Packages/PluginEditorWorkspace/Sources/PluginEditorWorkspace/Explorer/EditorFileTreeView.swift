import SwiftUI

public struct EditorFileTreeView: View {
    @ObservedObject private var controller: EditorWorkspaceController
    @StateObject private var model = EditorFileTreeModel()

    public init(controller: EditorWorkspaceController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            treeContent
        }
        .task(id: controller.rootURL) {
            await model.setRoot(controller.rootURL)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Explorer")
                .font(.headline)
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh Explorer")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var treeContent: some View {
        if let errorMessage = model.errorMessage {
            ContentUnavailableView(
                "Unable to open project",
                systemImage: "folder.badge.questionmark",
                description: Text(errorMessage)
            )
        } else if let root = model.root {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    FileTreeRow(
                        node: root,
                        depth: 0,
                        model: model,
                        controller: controller
                    )
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "No project open",
                systemImage: "folder",
                description: Text("Choose a project from the title bar to browse its files.")
            )
        }
    }
}

private struct FileTreeRow: View {
    @ObservedObject var node: EditorFileTreeNode
    let depth: Int
    @ObservedObject var model: EditorFileTreeModel
    @ObservedObject var controller: EditorWorkspaceController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: activate) {
                HStack(spacing: 5) {
                    if node.canExpand {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 10)
                    } else {
                        Color.clear.frame(width: 10, height: 1)
                    }
                    Image(systemName: EditorFileIcon.systemName(for: node))
                        .foregroundStyle(node.isDirectory ? .secondary : .primary)
                    Text(node.name)
                        .lineLimit(1)
                    if node.isLoading { ProgressView().controlSize(.mini) }
                    Spacer(minLength: 4)
                }
                .font(.system(size: 12))
                .padding(.leading, CGFloat(depth) * 14 + 6)
                .padding(.trailing, 6)
                .frame(height: 24)
                .background(selectionBackground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let error = node.errorMessage, node.isExpanded {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, CGFloat(depth + 1) * 14 + 20)
            }

            if node.isExpanded {
                ForEach(node.children ?? []) { child in
                    FileTreeRow(
                        node: child,
                        depth: depth + 1,
                        model: model,
                        controller: controller
                    )
                }
            }
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(controller.selectedFileURL == node.url ? Color.accentColor.opacity(0.18) : .clear)
            .padding(.horizontal, 3)
    }

    private func activate() {
        if node.canExpand {
            model.toggle(node)
        } else if !node.isDirectory {
            controller.openFile(node.url)
        }
    }
}
