import LumiCoreKit
import SwiftUI

/// Injects Git panel environment objects for the commit history workspace.
struct GitPanelHostView: View {
    let lumiCore: LumiCoreAccessing

    var body: some View {
        let gitVM = GitRuntimeBridge.gitVM
        GitCommitPanelView(
            lumiCore: lumiCore,
            gitVM: gitVM
        )
        .environmentObject(gitVM)
    }
}