import SwiftUI

struct CallHierarchyTreeView: View {
    let calls: [EditorCallHierarchyCall]
    let direction: CallHierarchyDirection
    let onSelect: (EditorCallHierarchyItem) -> Void

    enum CallHierarchyDirection {
        case incoming, outgoing
        var title: String { self == .incoming ? "调用者" : "被调用者" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(direction.title).font(.headline).padding(.horizontal).padding(.top, 8).padding(.bottom, 4)
            if calls.isEmpty {
                Text(String(localized: "无", table: "LSPCallHierarchyEditor") + direction.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(calls) { call in
                    CallHierarchyRowView(item: call.item, onSelect: onSelect)
                }
            }
        }
    }
}

struct CallHierarchyRowView: View {
    let item: EditorCallHierarchyItem
    let onSelect: (EditorCallHierarchyItem) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.iconSymbol).font(.system(size: 12)).frame(width: 16).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 13))
                Text(item.kindDisplayName).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4).padding(.horizontal, 8).contentShape(Rectangle())
        .onTapGesture { onSelect(item) }
    }
}
