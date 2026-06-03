import EditorService
import SwiftUI
import LumiUI

public struct CallHierarchyTreeView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let calls: [EditorCallHierarchyCall]
    public let direction: CallHierarchyDirection
    public let onSelect: (EditorCallHierarchyItem) -> Void

    public init(
        calls: [EditorCallHierarchyCall],
        direction: CallHierarchyDirection,
        onSelect: @escaping (EditorCallHierarchyItem) -> Void
    ) {
        self.calls = calls
        self.direction = direction
        self.onSelect = onSelect
    }

    public enum CallHierarchyDirection {
        case incoming, outgoing
        var title: String { self == .incoming ? "调用者" : "被调用者" }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(direction.title)
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            if calls.isEmpty {
                Text(String(localized: "无", bundle: .module) + direction.title)
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

public struct CallHierarchyRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let item: EditorCallHierarchyItem
    public let onSelect: (EditorCallHierarchyItem) -> Void

    public init(item: EditorCallHierarchyItem, onSelect: @escaping (EditorCallHierarchyItem) -> Void) {
        self.item = item
        self.onSelect = onSelect
    }

    public var body: some View {
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
