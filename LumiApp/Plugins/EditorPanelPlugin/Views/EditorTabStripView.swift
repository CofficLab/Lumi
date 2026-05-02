import SwiftUI
import MagicKit
import UniformTypeIdentifiers

struct EditorTabStripView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let tabs: [EditorTab]
    let activeSessionID: EditorSession.ID?
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

    @ViewBuilder
    private func tabItem(for tab: EditorTab) -> some View {
        let isActive = tab.sessionID == activeSessionID

        HoverRevealButton(
            isActive: isActive,
            isDirty: tab.isDirty,
            isPinned: tab.isPinned,
            title: tab.title,
            onSelect: { onSelect(tab) },
            onClose: { onClose(tab) },
            theme: theme
        )
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
}

// MARK: - HoverRevealButton

/// 单个标签页视图：关闭按钮默认隐藏，hover 或激活时显示
private struct HoverRevealButton: View {
    let isActive: Bool
    let isDirty: Bool
    let isPinned: Bool
    let title: String
    let onSelect: () -> Void
    let onClose: () -> Void
    let theme: any SuperTheme

    @State private var isHovered = false

    var body: some View {
        let showClose = isActive || isHovered

        HStack(spacing: 6) {
            if isDirty {
                Circle()
                    .fill(AppUI.Color.semantic.warning)
                    .frame(width: 6, height: 6)
            }

            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
            }

            Text(title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor())
                .lineLimit(1)

            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(theme.workspaceTertiaryTextColor())
                .frame(width: 14, height: 14)
                .contentShape(Rectangle())
                .opacity(showClose ? 1 : 0)
                .highPriorityGesture(TapGesture().onEnded {
                    onClose()
                })
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
        .onTapGesture {
            onSelect()
        }
        .onHover { hovered in
            isHovered = hovered
        }
    }
}
