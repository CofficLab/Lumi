import LumiKernel
import SwiftUI

/// Injects Git panel environment objects for the commit detail view.
///
/// The commit history list is now displayed in the rail sidebar via `panelRailTabItems`.
/// This view only shows the commit detail panel.
struct GitPanelHostView: View {
    let project: any ProjectProviding

    var body: some View {
        let gitVM = GitRuntimeBridge.gitVM
        GitCommitDetailView(project: project, gitVM: gitVM)
            .environmentObject(gitVM)
    }
}