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
                    EditorHeaderView(service: service)
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
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if !layoutState.railVisible {
                    Button {
                        layoutState.railVisible = true
                        layoutState.persistRailVisible()
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                }
                Button {
                    layoutState.bottomPanelVisible.toggle()
                    layoutState.persistBottomPanelVisible()
                } label: {
                    Image(systemName: "square.bottomthird.inset.filled")
                }
            }
        }
    }
}
