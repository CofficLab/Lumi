import EditorService
import SwiftUI
import LumiUI
import UniformTypeIdentifiers
import LumiCoreKit

/// 单个标签页的完整交互项
///
/// 封装了标签按钮、拖拽、放置排序以及右键上下文菜单。
public struct ItemView: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    @ObservedObject private var service: EditorService
    public let tab: EditorTab
    public let theme: any LumiAppChromeTheme
    public let onStartDrag: (EditorTab) -> Void
    public let onDropBefore: (EditorTab?) -> Void

    public init(
        service: EditorService,
        tab: EditorTab,
        theme: any LumiAppChromeTheme,
        onStartDrag: @escaping (EditorTab) -> Void,
        onDropBefore: @escaping (EditorTab?) -> Void
    ) {
        self._service = ObservedObject(wrappedValue: service)
        self.tab = tab
        self.theme = theme
        self.onStartDrag = onStartDrag
        self.onDropBefore = onDropBefore
    }

    private var isActive: Bool {
        service.sessions.activeSessionID == tab.sessionID
    }

    private var isDirty: Bool {
        tab.isDirty || (isActive && service.files.currentFileURL == tab.fileURL && service.files.hasUnsavedChanges)
    }

    private var tabIndex: Int? {
        service.sessions.tabs.firstIndex(where: { $0.sessionID == tab.sessionID })
    }

    private var canCloseTabsToLeft: Bool {
        guard let tabIndex else { return false }
        return tabIndex > 0
    }

    private var canCloseTabsToRight: Bool {
        guard let tabIndex else { return false }
        return tabIndex < service.sessions.tabs.count - 1
    }

    public var body: some View {
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
                    ? LumiPluginLocalization.string("Unpin Tab", bundle: .module)
                    : LumiPluginLocalization.string("Pin Tab", bundle: .module)
            ) {
                togglePinned()
            }
            Button(LumiPluginLocalization.string("Close Others", bundle: .module)) {
                closeOtherSessions()
            }
            Button(LumiPluginLocalization.string("Close Tabs to the Left", bundle: .module)) {
                closeTabsToLeft()
            }
            .disabled(!canCloseTabsToLeft)

            Button(LumiPluginLocalization.string("Close Tabs to the Right", bundle: .module)) {
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
                    .fill(uiTheme.warning)
                    .frame(width: 6, height: 6)
            }

            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.appMicro)
                    .foregroundColor(theme.workspaceTertiaryTextColor())
            }

            Text(tab.title)
                .font(isActive ? .appMicroEmphasized : .appMicro)
                .foregroundColor(isActive ? theme.workspaceTextColor() : theme.workspaceSecondaryTextColor())
                .lineLimit(1)

            Button {
                closeSession(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.workspaceTertiaryTextColor())
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showClose ? 1 : 0)
            .allowsHitTesting(showClose)
            .help(LumiPluginLocalization.string("Close Tab", bundle: .module))
            .simultaneousGesture(TapGesture().onEnded {
                // Prevent the parent tap handler from also activating the tab.
            })
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 28)
        .appSurface(
            style: .custom(theme.workspaceTextColor().opacity(backgroundOpacity)),
            cornerRadius: 7,
            borderColor: theme.workspaceTextColor().opacity(borderOpacity)
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
        service.sessions.activateAndRestoreSession(id: tab.sessionID)
    }

    private func closeSession(_ tab: EditorTab) {
        guard let session = service.sessions.session(for: tab.sessionID) else { return }
        let wasActive = session.id == service.sessions.activeSessionID
        if wasActive, service.files.hasUnsavedChanges {
            service.files.saveNow()
        }

        let nextSession = service.sessions.closeSession(id: session.id)
        guard wasActive, let nextSession else { return }

        // closeSession 已切换 activeSessionID，只需加载文件 + 恢复交互状态
        service.files.loadFile(from: nextSession.fileURL)
        service.files.applySessionRestore(nextSession)
    }

    // MARK: - Drag Preview

    private var tabDragPreview: some View {
        Group {
            if let fileURL = tab.fileURL {
                DragPreview(fileURL: fileURL)
            } else {
                Text(tab.title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(uiTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .appSurface(style: .custom(uiTheme.warning.opacity(0.95)), cornerRadius: 8)
            }
        }
    }

    // MARK: - 操作

    private func closeOtherSessions() {
        guard let session = service.sessions.session(for: tab.sessionID) else { return }
        if service.files.currentFileURL != session.fileURL, service.files.hasUnsavedChanges {
            service.files.saveNow()
        }

        let keptSession = service.sessions.closeOtherSessions(keeping: session.id)
        service.files.loadFile(from: keptSession?.fileURL)
        if let keptSession {
            service.files.applySessionRestore(keptSession)
        }
    }

    private func togglePinned() {
        service.sessions.togglePinned(sessionID: tab.sessionID)
    }

    private func closeTabsToLeft() {
        closeTabsOnSide(
            closesActiveSession: activeSessionIsLeftOfTab,
            close: { service.sessions.closeTabsToLeft(of: $0) }
        )
    }

    private func closeTabsToRight() {
        closeTabsOnSide(
            closesActiveSession: activeSessionIsRightOfTab,
            close: { service.sessions.closeTabsToRight(of: $0) }
        )
    }

    private func closeTabsOnSide(
        closesActiveSession: Bool,
        close: (EditorSession.ID) -> EditorSession?
    ) {
        let previousActiveSessionID = service.sessions.activeSessionID
        if closesActiveSession, service.files.hasUnsavedChanges {
            service.files.saveNow()
        }

        let nextSession = close(tab.sessionID)
        guard nextSession?.id != previousActiveSessionID else { return }

        service.files.loadFile(from: nextSession?.fileURL)
        if let nextSession {
            service.files.applySessionRestore(nextSession)
        }
    }

    private var activeSessionIsLeftOfTab: Bool {
        guard let activeSessionID = service.sessions.activeSessionID,
              let activeIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == activeSessionID }),
              let targetIndex = tabIndex else {
            return false
        }

        return activeIndex < targetIndex
    }

    private var activeSessionIsRightOfTab: Bool {
        guard let activeSessionID = service.sessions.activeSessionID,
              let activeIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == activeSessionID }),
              let targetIndex = tabIndex else {
            return false
        }

        return activeIndex > targetIndex
    }
}
