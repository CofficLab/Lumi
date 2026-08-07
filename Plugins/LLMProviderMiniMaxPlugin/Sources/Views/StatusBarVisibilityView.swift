import LumiKernel
import SwiftUI

struct StatusBarVisibilityView: View {
    // network 只在 body 里取实例传给 StatusBarView（它自带 Timer 驱动刷新），
    // 不需要观察其变更，故用 let。
    let kernel: LumiKernel

    // 只订阅 llmProvider 这一个 service：本视图用 selectedProviderID 做门控，
    // 不挂在 kernel 全局总线上，project/conversations/settings 等无关服务变更
    // 不会触发这里刷新。
    @StateObject private var providerBox = ObservableLLMProviderBox()

    private var selectedProviderID: String? {
        providerBox.service?.selectedProviderID
    }

    var body: some View {
        // 用 Group 包裹条件分支，并把 .task 挂在 Group 上：
        // 门控条件依赖 providerBox.service（绑定前为 nil），分支首次必为 false。
        // 若把 .task 挂进 if 内，分支不渲染时 bind 永不执行（死锁）。Group 恒存在，保证绑定。
        Group {
            if selectedProviderID == MiniMaxTokenPlanProvider.info.id || selectedProviderID == MiniMaxAnthropicProvider.info.id {
                StatusBarView(network: kernel.network)
            } else {
                EmptyView()
            }
        }
        .task { providerBox.bind(kernel.llmProvider) }
    }
}
