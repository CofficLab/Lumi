import LumiKernel
import SwiftUI

/// Only renders the quota view while Zhipu is the currently selected provider.
struct ZhipuStatusBarVisibilityView: View {
    @ObservedObject var kernel: LumiKernel

    private var selectedProviderID: String? {
        kernel.llmProvider?.selectedProviderID
    }

    var body: some View {
        if selectedProviderID == ZhipuProvider.info.id {
            StatusBarView(network: kernel.network)
        } else {
            EmptyView()
        }
    }
}
