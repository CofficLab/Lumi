import LumiCoreKit
import SwiftUI

struct GitPanelRootOverlay<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .environmentObject(GitRuntimeBridge.gitVM)
    }
}
