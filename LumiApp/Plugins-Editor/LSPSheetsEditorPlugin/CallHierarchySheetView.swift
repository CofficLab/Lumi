import SwiftUI

struct CallHierarchySheetView: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 760, idealWidth: 920, minHeight: 420, idealHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let root = state.callHierarchyProvider.rootItem {
                Image(systemName: root.iconSymbol)
                    .foregroundColor(.accentColor)
                Text(root.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(root.kindDisplayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("调用层级")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Button("关闭") {
                state.closeCallHierarchy()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if state.callHierarchyProvider.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("加载调用层级中...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.callHierarchyProvider.rootItem == nil {
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("未找到调用层级信息")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                CallHierarchyTreeView(
                    calls: state.callHierarchyProvider.incomingCalls,
                    direction: .incoming
                ) { item in
                    state.openCallHierarchyItem(item)
                }
                Divider()
                CallHierarchyTreeView(
                    calls: state.callHierarchyProvider.outgoingCalls,
                    direction: .outgoing
                ) { item in
                    state.openCallHierarchyItem(item)
                }
            }
        }
    }
}
