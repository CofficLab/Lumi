import SwiftUI
import MagicKit

struct EditorTabStripView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let tabs: [EditorTab]
    let activeSessionID: EditorSession.ID?
    let onStartDrag: (EditorTab) -> Void
    let onDropBefore: (EditorTab?) -> Void

    /// 当前主题
    private var theme: any SuperTheme {
        themeVM.activeAppTheme
    }

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        EditorTabItemView(
                            tab: tab,
                            isActive: tab.sessionID == activeSessionID,
                            theme: theme,
                            onStartDrag: onStartDrag,
                            onDropBefore: onDropBefore
                        )
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
}
