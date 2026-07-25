import SwiftUI
import LumiUI
import LumiKernel
import UniformTypeIdentifiers

/// 单个标签页的完整交互项
///
/// 封装了标签按钮、拖拽、放置排序以及右键上下文菜单。
/// 编辑器操作通过 `EditorTabStripCoordination` 协议委托,不直接依赖 EditorService。
public struct ItemView: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme

    @LumiMotionPreferenceReader private var motionPreference
    @State private var isHovered = false

    private let coordination: (any EditorTabStripCoordination)?
    private let allTabs: [TabDescriptor]
    private let activeSessionID: UUID?
    public let tab: TabDescriptor
    public let theme: any LumiAppChromeTheme
    public let onStartDrag: (TabDescriptor) -> Void
    public let onDropBefore: (TabDescriptor?) -> Void

    public init(
        coordination: (any EditorTabStripCoordination)?,
        allTabs: [TabDescriptor],
        activeSessionID: UUID?,
        tab: TabDescriptor,
        theme: any LumiAppChromeTheme,
        onStartDrag: @escaping (TabDescriptor) -> Void,
        onDropBefore: @escaping (TabDescriptor?) -> Void
    ) {
        self.coordination = coordination
        self.allTabs = allTabs
        self.activeSessionID = activeSessionID
        self.tab = tab
        self.theme = theme
        self.onStartDrag = onStartDrag
        self.onDropBefore = onDropBefore
    }

    private var isActive: Bool {
        activeSessionID == tab.sessionID
    }

    private var isDirty: Bool {
        tab.isDirty
    }

    private var tabIndex: Int? {
        allTabs.firstIndex(where: { $0.sessionID == tab.sessionID })
    }

    private var canCloseTabsToLeft: Bool {
        guard let tabIndex else { return false }
        return tabIndex > 0
    }

    private var canCloseTabsToRight: Bool {
        guard let tabIndex else { return false }
        return tabIndex < allTabs.count - 1
    }

    public var body: some View {
        tabContent
            .contentShape(Rectangle())
            .onTapGesture {
                coordination?.activateSession(id: tab.sessionID)
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
                    coordination?.togglePinned(sessionID: tab.sessionID)
                }
                Button(LumiPluginLocalization.string("Close Others", bundle: .module)) {
                    coordination?.closeOtherSessions(keeping: tab.sessionID)
                }
                Button(LumiPluginLocalization.string("Close Tabs to the Left", bundle: .module)) {
                    coordination?.closeTabsToLeft(of: tab.sessionID)
                }
                .disabled(!canCloseTabsToLeft)

                Button(LumiPluginLocalization.string("Close Tabs to the Right", bundle: .module)) {
                    coordination?.closeTabsToRight(of: tab.sessionID)
                }
                .disabled(!canCloseTabsToRight)
            }
            .onDrag {
                onStartDrag(tab)
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
                coordination?.closeSession(id: tab.sessionID)
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
}
