import LumiKernel
import SwiftUI

struct MiniMaxStatusBarVisibilityView: View {
    @ObservedObject var kernel: LumiKernel

    private var selectedProviderID: String? {
        kernel.llmProvider?.selectedProviderID
    }

    var body: some View {
        if selectedProviderID == MiniMaxTokenPlanProvider.info.id {
            StatusBarView(network: kernel.network)
        } else {
            EmptyView()
        }
    }
}
