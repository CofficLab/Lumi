import LumiKernel
import LumiUI
import SwiftUI

/// LLM Provider 设置 tab 的统一外壳。
///
/// 设计目的:
/// - 让 `SettingsTabItem` 的 contentBuilder 可以延迟处理依赖解析,
///   即"始终注册 tab,但只在依赖完整时渲染业务页面"。
/// - 业务页面 (`readyContent`) 仅在 `chatService` 与 `manager` 都成功解析时调用,
///   这从根本上杜绝了 `chatService` / `manager` 缺失时子视图空指针崩溃的可能。
/// - 依赖缺失时,顶部展示 `AppErrorBanner` 给醒目的红条,
///   下方展示 `DependenciesMissingDetailView` 提供完整的依赖清单与修复建议。
///
/// 之所以把这一层独立出来,而不是在 `LocalProviderSettingsPage` 内部分支处理:
/// 1. 两个 tab (Local / Remote) 共用同一套依赖解析,逻辑应一处维护。
/// 2. 业务页面保持"成功路径"代码整洁,错误兜底与它的渲染逻辑解耦。
struct ProviderDependencySettingsView<Ready: View>: View {
    @ObservedObject var dependencyState: SettingsTabDependencyState
    /// 仅在 `chatService` 与 `manager` 都成功解析时被调用,
    /// 接收已经校验过的依赖值,避免闭包内部再做判空。
    let readyContent: (any LumiChatServicing, LLMProviderManager) -> Ready

    init(
        dependencyState: SettingsTabDependencyState,
        readyContent: @escaping (any LumiChatServicing, LLMProviderManager) -> Ready
    ) {
        self.dependencyState = dependencyState
        self.readyContent = readyContent
    }

    var body: some View {
        Group {
            if let failure = nonReadyFailure {
                unavailableState(failure: failure)
            } else if let chatService = dependencyState.chatService,
                      let manager = dependencyState.manager {
                readyContent(chatService, manager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 理论上不可达(只要 `failure == nil` 两个字段就非空),
                // 但 SwiftUI ViewBuilder 必须有兜底分支。这里给个安全网。
                AppEmptyState(
                    icon: "questionmark.folder",
                    title: LumiPluginLocalization.string("settings.dependency.unknownState", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// 当 `isReady == false` 时返回 `failure`;否则返回 `nil`,
    /// 集中一处处理"是失败还是空状态"的判断,避免重复条件。
    private var nonReadyFailure: SettingsTabDependencyState.Failure? {
        guard !dependencyState.isReady else { return nil }
        return dependencyState.failure
    }

    /// 依赖缺失 —— banner + 依赖详情卡片。
    @ViewBuilder
    private func unavailableState(failure: SettingsTabDependencyState.Failure) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let description = failure.errorDescription {
                AppErrorBanner(
                    message: LocalizedStringKey(description),
                    retryTitle: LocalizedStringKey(
                        LumiPluginLocalization.string("settings.dependency.retry", bundle: .module)
                    ),
                    onRetry: {
                        // 重新触发 ObservableObject 通知,SwiftUI 会重走 body 渲染。
                        // 此时如果在宿主侧发生了异步注册,LumiCore 提供的服务也会
                        // 通过 `kernel.objectWillChange` 驱动外层 `SettingsView` 重新解析。
                        dependencyState.objectWillChange.send()
                    }
                )
            }

            DependenciesMissingDetailView(failure: failure)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
