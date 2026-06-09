import LumiCoreKit
import SwiftUI

/// Injects Git panel environment objects for the commit history workspace.
struct GitPanelHostView: View {
    @StateObject private var projectVM: WindowProjectVM

    init(projectPathStore: LumiCurrentProjectPathStore) {
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
    }

    var body: some View {
        GitCommitPanelView()
            .environmentObject(projectVM)
            .environmentObject(GitRuntimeBridge.gitVM)
    }
}
