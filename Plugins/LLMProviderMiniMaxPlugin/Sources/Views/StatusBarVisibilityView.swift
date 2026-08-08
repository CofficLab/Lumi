import LumiKernel
import SwiftUI

struct StatusBarVisibilityView: View {
    // network 只在 body 里取实例传给 StatusBarView（它自带 Timer 驱动刷新），
    // 不需要观察其变更，故用 let。
    let kernel: LumiKernel

    // selectedProviderID 由 provider 选择事件更新，用 @State 缓存做门控。
    // 不挂 kernel 全局总线。
    @State private var selectedProviderID: String?

    var body: some View {
        Group {
            if selectedProviderID == MiniMaxTokenPlanProvider.info.id
                || selectedProviderID == MiniMaxAnthropicProvider.info.id
                || selectedProviderID == MiniMaxResponsesProvider.info.id {
                StatusBarView(network: kernel.network)
            } else {
                EmptyView()
            }
        }
        .task {
            selectedProviderID = kernel.llmProvider?.selectedProviderID
        }
        .onLumiSelectedRemoteProviderIDDidChange {
            selectedProviderID = kernel.llmProvider?.selectedProviderID
        }
        .onLumiSelectedLocalProviderIDDidChange {
            selectedProviderID = kernel.llmProvider?.selectedProviderID
        }
    }
}
