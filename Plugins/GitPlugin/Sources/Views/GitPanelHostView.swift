import LumiKernel
import SwiftUI

/// Injects Git panel environment objects for the commit history workspace.
struct GitPanelHostView: View {
    let project: any ProjectProviding

    var body: some View {
        let gitVM = GitRuntimeBridge.gitVM
        GitCommitPanelView(
            project: project,
            gitVM: gitVM
        )
        .environmentObject(gitVM)
    }
}