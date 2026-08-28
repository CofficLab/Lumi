import SwiftUI

struct EditorTabStripView: View {
    @ObservedObject var controller: EditorWorkspaceController
    @Binding var pendingCloseTabID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(controller.editor.sessions.tabs) { tab in
                    let isActive = controller.editor.sessions.activeSessionID == tab.sessionID
                    Button {
                        controller.activateTab(id: tab.sessionID)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.isPinned ? "pin.fill" : "doc.text")
                                .font(.caption)
                            Text(tab.title)
                                .lineLimit(1)
                            Button {
                                if tab.isDirty {
                                    controller.activateTab(id: tab.sessionID)
                                    pendingCloseTabID = tab.sessionID
                                } else {
                                    controller.closeTab(id: tab.sessionID)
                                }
                            } label: {
                                Image(systemName: tab.isDirty ? "circle.fill" : "xmark")
                                    .font(.system(size: tab.isDirty ? 8 : 9, weight: .semibold))
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.plain)
                            .help(tab.isDirty ? "Unsaved changes" : "Close")
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                        .overlay(alignment: .bottom) {
                            if isActive { Color.accentColor.frame(height: 2) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
