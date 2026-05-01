import SwiftUI

struct EditorPanelView: View {
    var body: some View {
        EditorRootView()
    }
}

#Preview {
    EditorPanelView()
        .inRootView()
        .frame(width: 1200, height: 600)
}
