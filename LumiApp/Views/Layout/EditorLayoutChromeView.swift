import SwiftUI

struct EditorLayoutChromeView: View {
    @ObservedObject var layoutState: EditorPanelLayoutState

    var body: some View {
        HStack(spacing: 4) {
            if !layoutState.railVisible {
                Button {
                    layoutState.railVisible = true
                    layoutState.persistRailVisible()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help("Show Sidebar")
            }

            Button {
                layoutState.bottomPanelVisible.toggle()
                layoutState.persistBottomPanelVisible()
            } label: {
                Image(systemName: "square.bottomthird.inset.filled")
            }
            .buttonStyle(.borderless)
            .help("Toggle Bottom Panel")
        }
        .padding(.trailing, 8)
    }
}
