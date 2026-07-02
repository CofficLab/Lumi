import LumiCoreKit
import SwiftUI

/// Injects Git panel environment objects for the commit history workspace.
struct GitPanelHostView: View {
    var body: some View {
        GitCommitPanelView()
            .environmentObject(GitRuntimeBridge.gitVM)
    }
}
