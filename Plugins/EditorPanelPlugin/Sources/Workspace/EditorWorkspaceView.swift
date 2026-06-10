import EditorService
import LumiUI
import SwiftUI

struct EditorWorkspaceView: View {
    @LumiTheme private var theme
    @StateObject private var layoutState = EditorWorkspaceLayoutState()
    @ObservedObject private var service: EditorService

    init(service: EditorService) {
        self._service = ObservedObject(wrappedValue: service)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if layoutState.railVisible {
                    EditorRailView(layoutState: layoutState, service: service)
                    Divider()
                }

                VStack(spacing: 0) {
                    EditorHeaderView(layoutState: layoutState, service: service)
                    Divider()
                    EditorPanelView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if layoutState.bottomPanelVisible {
                        Divider()
                        EditorBottomPanelView(layoutState: layoutState, service: service)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
    }
}
