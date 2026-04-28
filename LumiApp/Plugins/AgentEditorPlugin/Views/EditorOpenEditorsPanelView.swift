import SwiftUI
import MagicKit

struct EditorOpenEditorsPanelView: View {
    private struct SectionModel: Identifiable {
        let id: String
        let title: String
        let items: [EditorOpenEditorItem]
    }

    @ObservedObject var state: EditorState
    let items: [EditorOpenEditorItem]
    let onSelect: (EditorOpenEditorItem) -> Void
    let onClose: (EditorOpenEditorItem) -> Void
    let onCloseOthers: (EditorOpenEditorItem) -> Void
    let onTogglePinned: (EditorOpenEditorItem) -> Void

    @State private var dragStartWidth: CGFloat?
    @State private var isResizeHandleHovering = false
    @State private var collapsedSectionIDs = Set<String>()

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle

            VStack(spacing: 0) {
                header
                GlassDivider()
                content
            }
            .frame(width: state.sidePanelWidth)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                Rectangle()
                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.12))
                    .frame(width: 1),
                alignment: .leading
            )
        }
        .onAppear {
            syncCollapsedSections()
        }
        .onChange(of: sections.map(\.id)) { _, _ in
            syncCollapsedSections()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(String(localized: "Open Editors", table: "LumiEditor") + " (\(items.count))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeOpenEditors)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                toggleSection(section.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isCollapsed(section.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(AppUI.Color.semantic.textTertiary)

                                    Text(section.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(AppUI.Color.semantic.textTertiary)

                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)

                            if !isCollapsed(section.id) {
                                ForEach(section.items) { item in
                                    Button {
                                        onSelect(item)
                                    } label: {
                                        row(for: item)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(
                                            item.isPinned
                                                ? String(localized: "Unpin Tab", table: "LumiEditor")
                                                : String(localized: "Pin Tab", table: "LumiEditor")
                                        ) {
                                            onTogglePinned(item)
                                        }
                                        Button(String(localized: "Close Others", table: "LumiEditor")) {
                                            onCloseOthers(item)
                                        }
                                        Button(String(localized: "Close", table: "LumiEditor")) {
                                            onClose(item)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 26, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "No Open Editors", table: "LumiEditor"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .background(
                isResizeHandleHovering
                    ? AppUI.Color.semantic.primary.opacity(0.08)
                    : .clear
            )
            .overlay(
                Rectangle()
                    .fill(
                        isResizeHandleHovering
                            ? AppUI.Color.semantic.primary.opacity(0.5)
                            : AppUI.Color.semantic.textTertiary.opacity(0.12)
                    )
                    .frame(width: 1)
            )
            .onHover { isHovering in
                isResizeHandleHovering = isHovering
                if isHovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartWidth == nil {
                            dragStartWidth = state.sidePanelWidth
                        }
                        let baseWidth = dragStartWidth ?? state.sidePanelWidth
                        state.sidePanelWidth = CGFloat(min(max(baseWidth - value.translation.width, 240), 720))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                        state.persistSidePanelWidth()
                    }
            )
    }

    private var sections: [SectionModel] {
        let recentItems = items
            .filter { ($0.recentActivationRank ?? .max) < 5 }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }
                if lhs.recentActivationRank != rhs.recentActivationRank {
                    return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        let activeGroupItems = items.filter(\.isInActiveGroup)
        let otherGroupItems = Dictionary(grouping: items.filter { !$0.isInActiveGroup && $0.groupID != nil }) {
            $0.groupIndex ?? .max
        }
        let unassignedItems = items.filter { $0.groupID == nil }

        var result: [SectionModel] = []

        if recentItems.count > 1 {
            result.append(
                SectionModel(
                    id: "recent",
                    title: String(localized: "Recently Active", table: "LumiEditor"),
                    items: recentItems
                )
            )
        }

        if !activeGroupItems.isEmpty {
            result.append(
                SectionModel(
                    id: "active-group",
                    title: String(localized: "Current Group", table: "LumiEditor"),
                    items: sortSectionItems(activeGroupItems)
                )
            )
        }

        result.append(
            contentsOf: otherGroupItems.keys.sorted().compactMap { groupIndex in
                guard let items = otherGroupItems[groupIndex], !items.isEmpty else { return nil }
                return SectionModel(
                    id: "group-\(groupIndex)",
                    title: String(localized: "Group \(groupIndex + 1)", table: "LumiEditor"),
                    items: sortSectionItems(items)
                )
            }
        )

        if !unassignedItems.isEmpty {
            result.append(
                SectionModel(
                    id: "unassigned",
                    title: String(localized: "Other Open Editors", table: "LumiEditor"),
                    items: sortSectionItems(unassignedItems)
                )
            )
        }

        return result
    }

    private func row(for item: EditorOpenEditorItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.isDirty ? AppUI.Color.semantic.warning : AppUI.Color.semantic.textTertiary.opacity(0.35))
                .frame(width: 6, height: 6)

            if let groupIndex = item.groupIndex {
                Text("G\(groupIndex + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(item.isInActiveGroup ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textTertiary)
            }

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }

            if let recentActivationRank = item.recentActivationRank, recentActivationRank < 3 {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8))
                    .foregroundColor(AppUI.Color.semantic.primary)
            }

            Text(item.title)
                .font(.system(size: 11, weight: item.isActive ? .semibold : .regular))
                .foregroundColor(item.isActive ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if item.isActive {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundColor(AppUI.Color.semantic.primary)
            }

            Button {
                onClose(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    item.isActive
                        ? AppUI.Color.semantic.primary.opacity(0.12)
                        : AppUI.Color.semantic.textTertiary.opacity(0.06)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    item.isActive
                        ? AppUI.Color.semantic.primary.opacity(0.4)
                        : .clear,
                    lineWidth: 1
                )
        )
    }

    private func isCollapsed(_ sectionID: String) -> Bool {
        collapsedSectionIDs.contains(sectionID)
    }

    private func toggleSection(_ sectionID: String) {
        if collapsedSectionIDs.contains(sectionID) {
            collapsedSectionIDs.remove(sectionID)
        } else {
            collapsedSectionIDs.insert(sectionID)
        }
    }

    private func syncCollapsedSections() {
        let validIDs = Set(sections.map(\.id))
        collapsedSectionIDs = collapsedSectionIDs.intersection(validIDs)

        for section in sections {
            switch section.id {
            case "recent", "active-group":
                collapsedSectionIDs.remove(section.id)
            default:
                if !collapsedSectionIDs.contains(section.id) && !section.items.isEmpty {
                    collapsedSectionIDs.insert(section.id)
                }
            }
        }
    }

    private func sortSectionItems(_ items: [EditorOpenEditorItem]) -> [EditorOpenEditorItem] {
        items.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.recentActivationRank != rhs.recentActivationRank {
                return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
            }
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
