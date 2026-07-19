import LumiKernel
import SwiftUI

struct GitPanelRootOverlay<Content: View>: View {
    let lumiCore: LumiCoreAccessing
    let content: Content

    var body: some View {
        let gitVM = GitRuntimeBridge.gitVM
        GitCommitHistoryRootOverlay(
            gitVM: gitVM,
            lumiCore: lumiCore
        ) {
            content
        }
        .environmentObject(gitVM)
    }
}