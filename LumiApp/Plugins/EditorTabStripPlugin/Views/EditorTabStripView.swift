import SwiftUI
import MagicKit
import UniformTypeIdentifiers

struct EditorTabStripView: View {
    @EnvironmentObject var editorVM: EditorVM
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject private var themeManager: ThemeManager

    let tabs: [EditorTab]
    let activeSessionID: EditorSession.ID?
    let onStartDrag: (EditorTab) -> Void
    let onDropBefore: (EditorTab?) -> Void

    var service: EditorService { editorVM.service }
    var sessionStore: EditorSessionStore { service.sessionStore }
    var state: EditorState { service.state }

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

    // MARK: - Tab Item

    @ViewBuilder
    private func tabItem(for tab: EditorTab) -> some View {
        let isActive = tab.sessionID == activeSessionID

        HoverRevealButton(
            tab: tab,
            isActive: isActive,
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
                togglePinned(tab)
            }
            Button(String(localized: "Close Others", table: "LumiEditor")) {
                closeOtherSessions(tab)
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

    // MARK: - 操作

    private func closeOtherSessions(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        if state.currentFileURL != session.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }

        let keptSession = sessionStore.closeOthers(keeping: session.id)
        if let fileURL = keptSession?.fileURL {
            projectVM.selectFile(at: fileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func togglePinned(_ tab: EditorTab) {
        sessionStore.togglePinned(sessionID: tab.sessionID)
    }
}
