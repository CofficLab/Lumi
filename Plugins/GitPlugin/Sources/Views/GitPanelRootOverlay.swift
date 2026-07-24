import LumiKernel
import SwiftUI

struct GitPanelRootOverlay<Content: View>: View {
    let project: any ProjectProviding
    let content: Content

    var body: some View {
        let gitVM = GitRuntimeBridge.gitVM
        GitCommitHistoryRootOverlay(
            gitVM: gitVM,
            project: project
        ) {
            content
        }
        .environmentObject(gitVM)
    }
}