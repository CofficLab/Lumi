import Foundation
import LumiKernel
import SwiftUI

/// 解析 LLM Provider 设置 tab 运行时所需的内核依赖。
///
/// 这是一个轻量级值类型,把"依赖解析是否成功"以及"具体缺了什么"
/// 显式地暴露给 SwiftUI 视图,以便在依赖缺失时仍能渲染 tab 内容
/// —— 顶部展示 `AppErrorBanner`,下方展示 `DependenciesMissingDetailView`,
/// 而不是让整个 tab 从侧边栏消失。
///
/// 设计动机:`LLMProviderManagerPlugin.settingsTabItems` 之前的实现是在
/// 依赖缺失时静默返回空数组,导致 "Local Providers" / "Cloud Providers"
/// 两个 tab 完全不显示,用户毫无线索。新版始终注册 tab,具体错误通过本状态
/// 对象在视图层渲染。
@MainActor
public final class SettingsTabDependencyState: ObservableObject {
    /// 依赖解析的具体失败原因。
    ///
    /// 按"最先缺失"的顺序列出:`missingLumiCore` → `missingChatService` → `missingManager`。
    public enum Failure: LocalizedError, Equatable {
        /// 内核尚未提供 `LumiCore`(宿主尚未完成 bootstrap)。
        case missingLumiCore
        /// `LumiCore` 已就绪,但未注册 `LumiChatServicing`(聊天服务插件未加载或未启用)。
        case missingChatService
        /// `LLM Provider Manager` 服务未注册(自身的 `onBoot` 异常或顺序错乱)。
        case missingManager

        public var errorDescription: String? {
            switch self {
            case .missingLumiCore:
                return LumiPluginLocalization.string(
                    "settings.dependency.missingLumiCore",
                    bundle: .module
                )
            case .missingChatService:
                return LumiPluginLocalization.string(
                    "settings.dependency.missingChatService",
                    bundle: .module
                )
            case .missingManager:
                return LumiPluginLocalization.string(
                    "settings.dependency.missingManager",
                    bundle: .module
                )
            }
        }
    }

    public let failure: Failure?
    public let chatService: (any LumiChatServicing)?
    public let manager: LLMProviderManager?
    public let providerSettingsViews: [LumiLLMProviderSettingsViewItem]

    public var isReady: Bool { failure == nil }

    private init(
        failure: Failure?,
        chatService: (any LumiChatServicing)?,
        manager: LLMProviderManager?,
        providerSettingsViews: [LumiLLMProviderSettingsViewItem]
    ) {
        self.failure = failure
        self.chatService = chatService
        self.manager = manager
        self.providerSettingsViews = providerSettingsViews
    }

    /// 解析依赖,返回对应的状态(成功/失败)。
    ///
    /// - Parameters:
    ///   - kernel: 当前内核实例。
    ///   - managerAccessor: 直接可用的本地 manager 引用(由插件实例属性持有)。
    ///     使用 `@autoclosure` 是为了在 `manager` 已就绪时跳过 `kernel.resolveService` 的反射查找。
    public static func resolve(
        kernel: LumiKernel,
        managerAccessor: @autoclosure @escaping () -> LLMProviderManager?
    ) -> SettingsTabDependencyState {
        guard let lumiCore = kernel.lumiCore else {
            return SettingsTabDependencyState(
                failure: .missingLumiCore,
                chatService: nil,
                manager: nil,
                providerSettingsViews: []
            )
        }

        guard let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return SettingsTabDependencyState(
                failure: .missingChatService,
                chatService: nil,
                manager: nil,
                providerSettingsViews: []
            )
        }

        // 优先用本地引用(已设置 `manager` 的实例),回退到 kernel 服务表查找。
        let resolvedManager: LLMProviderManager?
        if let local = managerAccessor() {
            resolvedManager = local
        } else if let anyManager = kernel.resolveService((any LumiLLMProviderSettingsContributing).self) {
            resolvedManager = anyManager as? LLMProviderManager
        } else {
            resolvedManager = nil
        }

        guard let manager = resolvedManager else {
            return SettingsTabDependencyState(
                failure: .missingManager,
                chatService: chatService,
                manager: nil,
                providerSettingsViews: []
            )
        }

        let views = manager.llmProviderSettingsViews(lumiCore: lumiCore)
        return SettingsTabDependencyState(
            failure: nil,
            chatService: chatService,
            manager: manager,
            providerSettingsViews: views
        )
    }
}
