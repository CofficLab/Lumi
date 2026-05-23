import SwiftUI
import LumiUI

struct CallHierarchyTreeView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let calls: [EditorCallHierarchyCall]
    let direction: CallHierarchyDirection
    let onSelect: (EditorCallHierarchyItem) -> Void

    enum CallHierarchyDirection {
        case incoming, outgoing
        var title: String { self == .incoming ? "调用者" : "被调用者" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(direction.title)
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            if calls.isEmpty {
                Text(String(localized: "无", table: "LSPCallHierarchyEditor") + direction.title)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let item: EditorCallHierarchyItem
    let onSelect: (EditorCallHierarchyItem) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.iconSymbol)
                .font(.appCaption)
                .frame(width: 16)
                .foregroundColor(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
                Text(item.kindDisplayName)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(item) }
    }
}
