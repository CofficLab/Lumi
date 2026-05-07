import SwiftUI
import MagicKit
import UniformTypeIdentifiers

/// 单个标签页的完整交互项
///
/// 封装了标签按钮、拖拽、放置排序以及右键上下文菜单。
struct EditorTabItemView: View {
    @EnvironmentObject var editorVM: EditorVM

    let tab: EditorTab
    let isActive: Bool
    let theme: any SuperTheme
    let onStartDrag: (EditorTab) -> Void
    let onDropBefore: (EditorTab?) -> Void

    var service: EditorService { editorVM.service }
    var sessionStore: EditorSessionStore { service.sessionStore }
    var state: EditorState { service.state }

    var body: some View {
        Button(action: {
            activateSession(tab)
        }) {
            HoverRevealButton(
                tab: tab,
                isActive: isActive,
                theme: theme
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
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
        }
        .onDrag {
            onStartDrag(tab)
            return NSItemProvider(object: tab.sessionID.uuidString as NSString)
        } preview: {
            tabDragPreview
        }
    }

    // MARK: - 操作

    private func activateSession(_ tab: EditorTab) {
        guard let session = sessionStore.activate(sessionID: tab.sessionID) else { return }
        state.loadFile(from: session.fileURL)
        state.applySessionRestore(session)
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
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        if state.currentFileURL != session.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }

        let keptSession = sessionStore.closeOthers(keeping: session.id)
        state.loadFile(from: keptSession?.fileURL)
        if let keptSession {
            state.applySessionRestore(keptSession)
        }
    }

    private func togglePinned() {
        sessionStore.togglePinned(sessionID: tab.sessionID)
    }
}
