import EditorService
import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Panel Chrome Command Handler

/// Handles panel chrome commands (toggle outline panel, toggle open editors panel)
struct PanelChromeCommandHandler: ViewModifier {
    @ObservedObject var layoutState: LayoutState

    private var notifications: EditorHostEnvironment.Notifications {
        EditorHostEnvironment.current.notifications
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: notifications.toggleOutlinePanel)) { _ in
                layoutState.presentRailTab(id: "outline")
            }
            .onReceive(NotificationCenter.default.publisher(for: notifications.toggleOpenEditorsPanel)) { _ in
                layoutState.presentRailTab(id: "explorer")
            }
    }
}
