import SwiftUI
import MagicKit
import UniformTypeIdentifiers

struct EditorTabStripView: View {
    private struct OpenEditorSection: Identifiable {
        let id: String
        let title: String
        let items: [EditorOpenEditorItem]
    }

    @EnvironmentObject private var themeManager: ThemeManager
    let tabs: [EditorTab]
    let activeSessionID: EditorSession.ID?
    let openEditors: [EditorOpenEditorItem]
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    let onToggleOpenEditorsPanel: () -> Void
    let onSelectOpenEditor: (EditorOpenEditorItem) -> Void
    let onSelect: (EditorTab) -> Void
    let onClose: (EditorTab) -> Void
    let onCloseOthers: (EditorTab) -> Void
    let onTogglePinned: (EditorTab) -> Void
    let onStartDrag: (EditorTab) -> Void
    let onDropBefore: (EditorTab?) -> Void

    /// 当前主题
    private var theme: any SuperTheme {
        themeManager.activeAppTheme
    }

    var body: some View {
        HStack(spacing: 4) {
            navigationButton(
                systemName: "chevron.left",
                isEnabled: canNavigateBack,
                action: onNavigateBack
            )

            navigationButton(
                systemName: "chevron.right",
                isEnabled: canNavigateForward,
                action: onNavigateForward
            )

            if !openEditors.isEmpty {
                openEditorsMenu
                openEditorsPanelButton
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabItem(for: tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .onDrop(of: [.plainText], isTargeted: nil) { _ in
                    onDropBefore(nil)
                    return true
                }
            }
        }
        .background(theme.workspaceTertiaryTextColor().opacity(0.06))
    }

    private var openEditorsMenu: some View {
        Menu {
            Group {
                ForEach(openEditorSections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            Button {
                                onSelectOpenEditor(item)
                            } label: {
                                openEditorLabel(for: item)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 220)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(openEditors.count)")
                    .font(.system(size: 10, weight: .medium))
                if openEditors.contains(where: \.isInActiveGroup) {
                    Divider()
                        .frame(height: 10)
                    Text("G")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundColor(theme.workspaceSecondaryTextColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.workspaceTextColor().opacity(0.05))
            )
        }
        .menuStyle(.borderlessButton)
    }

    private var openEditorsPanelButton: some View {
        Button(action: onToggleOpenEditorsPanel) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.workspaceTextColor().opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private var openEditorSections: [OpenEditorSection] {
        let activeGroupItems = openEditors.filter(\.isInActiveGroup)
        let unassignedItems = openEditors.filter { $0.groupID == nil }

        let groupedOtherItems = Dictionary(grouping: openEditors.filter {
            !$0.isInActiveGroup && $0.groupID != nil
        }) { item in
            item.groupIndex ?? .max
        }

        var sections: [OpenEditorSection] = []

        if !activeGroupItems.isEmpty {
            sections.append(
                OpenEditorSection(
                    id: "active-group",
                    title: String(
                        localized: "Current Group (\(activeGroupItems.count))",
                        table: "LumiEditor"
                    ),
                    items: activeGroupItems
                )
            )
        }

        sections.append(
            contentsOf: groupedOtherItems.keys
                .sorted()
                .compactMap { groupIndex in
                    guard let items = groupedOtherItems[groupIndex], !items.isEmpty else { return nil }
                    return OpenEditorSection(
                        id: "group-\(groupIndex)",
                        title: String(
                            localized: "Group \(groupIndex + 1) (\(items.count))",
                            table: "LumiEditor"
                        ),
                        items: items
                    )
                }
        )

        if !unassignedItems.isEmpty {
            sections.append(
                OpenEditorSection(
                    id: "unassigned",
                    title: String(
                        localized: "Other Open Editors (\(unassignedItems.count))",
                        table: "LumiEditor"
                    ),
                    items: unassignedItems
                )
            )
        }

        return sections
    }

    private func openEditorLabel(for item: EditorOpenEditorItem) -> some View {
        HStack(spacing: 8) {
            if let groupIndex = item.groupIndex {
                Text("G\(groupIndex + 1)")
                    .foregroundColor(item.isInActiveGroup ? theme.workspaceTextColor() : theme.workspaceTertiaryTextColor())
            }
            if item.isActive {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
            }
            if let recentActivationRank = item.recentActivationRank, recentActivationRank < 3 {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 8))
            }
            Text(item.title)
            if item.isDirty {
                Text("•")
            }
        }
    }

    private func tabItem(for tab: EditorTab) -> some View {
        let isActive = tab.sessionID == activeSessionID

        return HStack(spacing: 6) {
            Circle()
                .fill(tab.isDirty ? AppUI.Color.semantic.warning : theme.workspaceTertiaryTextColor().opacity(0.35))
                .frame(width: 6, height: 6)

            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
            }

            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor())
                .lineLimit(1)

            Button {
                onClose(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? theme.workspaceTextColor().opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? theme.workspaceTextColor().opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(tab)
        }
        .onDrag {
            onStartDrag(tab)
            return NSItemProvider(object: tab.sessionID.uuidString as NSString)
        } preview: {
            tabDragPreview(for: tab)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { _ in
            onDropBefore(tab)
            return true
        }
        .contextMenu {
            Button(
                tab.isPinned
                    ? String(localized: "Unpin Tab", table: "LumiEditor")
                    : String(localized: "Pin Tab", table: "LumiEditor")
            ) {
                onTogglePinned(tab)
            }
            Button(String(localized: "Close Others", table: "LumiEditor")) {
                onCloseOthers(tab)
            }
        }
    }

    private func tabDragPreview(for tab: EditorTab) -> some View {
        Group {
            if let fileURL = tab.fileURL {
                DragPreview(fileURL: fileURL)
            } else {
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.95))
                    )
            }
        }
    }

    private func navigationButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isEnabled ? theme.workspaceSecondaryTextColor() : theme.workspaceTertiaryTextColor().opacity(0.5))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isEnabled ? theme.workspaceTextColor().opacity(0.05) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.leading, systemName == "chevron.left" ? 8 : 0)
    }
}
