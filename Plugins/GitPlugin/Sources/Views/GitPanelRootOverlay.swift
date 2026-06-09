import LumiCoreKit
import SwiftUI

struct GitPanelRootOverlay<Content: View>: View {
    let content: Content
    @StateObject private var projectVM: WindowProjectVM

    init(content: Content, projectPathStore: LumiCurrentProjectPathStore) {
        self.content = content
        _projectVM = StateObject(wrappedValue: WindowProjectVM(store: projectPathStore))
    }

    var body: some View {
        GitCommitHistoryRootOverlay(content: content)
            .environmentObject(projectVM)
            .environmentObject(GitRuntimeBridge.gitVM)
    }
}
