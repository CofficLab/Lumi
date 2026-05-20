import SwiftUI
import LumiUI
import MagicKit
import UniformTypeIdentifiers

/// 单个标签页的完整交互项
///
/// 封装了标签按钮、拖拽、放置排序以及右键上下文菜单。
struct EditorTabItemView: View {
    @EnvironmentObject var editorVM: WindowEditorVM
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    let tab: EditorTab
    let theme: any SuperTheme
    let onStartDrag: (EditorTab) -> Void
    let onDropBefore: (EditorTab?) -> Void

    var service: EditorService { editorVM.service }

    private var isActive: Bool {
        service.activeSessionID == tab.sessionID
    }

    private var isDirty: Bool {
        tab.isDirty || (isActive && service.currentFileURL == tab.fileURL && service.hasUnsavedChanges)
    }

    private var tabIndex: Int? {
        service.tabs.firstIndex(where: { $0.sessionID == tab.sessionID })
    }

    private var canCloseTabsToLeft: Bool {
        guard let tabIndex else { return false }
        return tabIndex > 0
    }

    private var canCloseTabsToRight: Bool {
        guard let tabIndex else { return false }
        return tabIndex < service.tabs.count - 1
    }

    var body: some View {
        tabContent
        .contentShape(Rectangle())
        .onTapGesture {
            activateSession(tab)
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
                togglePinned()
            }
            Button(String(localized: "Close Others", table: "LumiEditor")) {
                closeOtherSessions()
            }
            Button(String(localized: "Close Tabs to the Left", table: "LumiEditor")) {
                closeTabsToLeft()
            }
            .disabled(!canCloseTabsToLeft)

            Button(String(localized: "Close Tabs to the Right", table: "LumiEditor")) {
                closeTabsToRight()
            }
            .disabled(!canCloseTabsToRight)
        }
        .onDrag {
            onStartDrag(tab)
            // 传递绝对路径纯文本，便于拖入输入框等；标签排序仍靠 onStartDrag 状态
            if let path = tab.fileURL?.path {
                return NSItemProvider(object: path as NSString)
            }
            return NSItemProvider(object: tab.sessionID.uuidString as NSString)
        } preview: {
            tabDragPreview
        }
    }

    private var tabContent: some View {
        let showClose = isActive || isHovered
        let backgroundOpacity = isActive ? 0.07 : (isHovered ? 0.04 : 0)
        let borderOpacity = isActive ? 0.08 : (isHovered ? 0.05 : 0)

        return HStack(spacing: 6) {
            if isDirty {
                Circle()
                    .fill(Color(hex: "FF9F0A"))
                    .frame(width: 6, height: 6)
            }

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
                closeSession(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.workspaceTertiaryTextColor())
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showClose ? 1 : 0)
            .allowsHitTesting(showClose)
            .help(String(localized: "Close Tab", table: "LumiEditor"))
            .simultaneousGesture(TapGesture().onEnded {
                // Prevent the parent tap handler from also activating the tab.
            })
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.workspaceTextColor().opacity(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(theme.workspaceTextColor().opacity(borderOpacity), lineWidth: 1)
        )
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovered)
        .animation(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference), value: isActive)
        .onHover { hovered in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovered
            }
        }
    }

    // MARK: - 操作

    private func activateSession(_ tab: EditorTab) {
        service.activateAndRestoreSession(id: tab.sessionID)
    }

    private func closeSession(_ tab: EditorTab) {
        guard let session = service.session(for: tab.sessionID) else { return }
        let wasActive = session.id == service.activeSessionID
        if wasActive, service.hasUnsavedChanges {
            service.saveNow()
        }

        let nextSession = service.closeSession(id: session.id)
        guard wasActive, let nextSession else { return }

        // closeSession 已切换 activeSessionID，只需加载文件 + 恢复交互状态
        service.loadFile(from: nextSession.fileURL)
        service.applySessionRestore(nextSession)
    }

    // MARK: - Drag Preview

    private var tabDragPreview: some View {
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

    // MARK: - 操作

    private func closeOtherSessions() {
        guard let session = service.session(for: tab.sessionID) else { return }
        if service.currentFileURL != session.fileURL, service.hasUnsavedChanges {
            service.saveNow()
        }

        let keptSession = service.closeOtherSessions(keeping: session.id)
        service.loadFile(from: keptSession?.fileURL)
        if let keptSession {
            service.applySessionRestore(keptSession)
        }
    }

    private func togglePinned() {
        service.togglePinned(sessionID: tab.sessionID)
    }

    private func closeTabsToLeft() {
        closeTabsOnSide(
            closesActiveSession: activeSessionIsLeftOfTab,
            close: { service.closeTabsToLeft(of: $0) }
        )
    }

    private func closeTabsToRight() {
        closeTabsOnSide(
            closesActiveSession: activeSessionIsRightOfTab,
            close: { service.closeTabsToRight(of: $0) }
        )
    }

    private func closeTabsOnSide(
        closesActiveSession: Bool,
        close: (EditorSession.ID) -> EditorSession?
    ) {
        let previousActiveSessionID = service.activeSessionID
        if closesActiveSession, service.hasUnsavedChanges {
            service.saveNow()
        }

        let nextSession = close(tab.sessionID)
        guard nextSession?.id != previousActiveSessionID else { return }

        service.loadFile(from: nextSession?.fileURL)
        if let nextSession {
            service.applySessionRestore(nextSession)
        }
    }

    private var activeSessionIsLeftOfTab: Bool {
        guard let activeSessionID = service.activeSessionID,
              let activeIndex = service.tabs.firstIndex(where: { $0.sessionID == activeSessionID }),
              let targetIndex = tabIndex else {
            return false
        }

        return activeIndex < targetIndex
    }

    private var activeSessionIsRightOfTab: Bool {
        guard let activeSessionID = service.activeSessionID,
              let activeIndex = service.tabs.firstIndex(where: { $0.sessionID == activeSessionID }),
              let targetIndex = tabIndex else {
            return false
        }

        return activeIndex > targetIndex
    }
}
