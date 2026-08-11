import LumiKernel
import LumiUI
import SwiftUI

let stepFunPluginDataDirectoryName = "LLMProviderStepFunPlugin"

@MainActor
public final class StepFunPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.stepfun"
    public var name: String = "StepFun StepPlan"

    public let order = 93
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    /// 子 Agent 依赖 StepFun 模型,因此它们的生命周期绑定到这个 provider 实例。
    ///
    /// 持有单例(而非每次 `llmProviders(kernel:)` 都新建)有两个原因:
    /// 1. `StepFunSubAgentsGate` 需要复用同一个 provider 去做可用性探测,且需共享它的
    ///    `AvailabilityDiskCache`,避免探测/注册两条路径各持一个 provider、缓存分裂。
    /// 2. boot 时序里 provider 注册与可用性探测需要共享同一个 provider 实例,
    ///    provider 不在 kernel registry 中 —— 持有自己的实例,gate 在任何时点都能探测。
    ///
    /// 用 `private var` + 懒初始化(而非 `private let`),因为初始化 provider 需要 kernel,
    /// 而构造 plugin 时尚拿不到 kernel。
    private var provider: StepFunProvider?
    private var gate: StepFunSubAgentsGate?

    /// 懒构造 provider + gate(幂等,首次调用时创建)。
    private func ensureProvider(kernel: LumiKernel) -> StepFunProvider {
        if let provider { return provider }
        let network = kernel.network
        let instance = StepFunProvider(network: network)
        provider = instance
        gate = StepFunSubAgentsGate(provider: instance)
        return instance
    }

    public func onBoot(kernel: LumiKernel) async throws {
        if let storage = kernel.storage {
            AvailabilityDiskCacheDirectoryResolver.set(
                pluginName: stepFunPluginDataDirectoryName,
                directory: storage.pluginDataDirectory(for: stepFunPluginDataDirectoryName)
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {
        // 确保 provider/gate 就绪,然后异步探测供应商可用性。
        // 用 Task 包裹,绝不阻塞 kernel 启动;探测完成后由 gate 自行触发一次
        // `rebuildAllContributions` 让框架重新收集 sub-agent(若此时已 ready)。
        _ = ensureProvider(kernel: kernel)
        guard let gate else { return }
        Task { @MainActor in
            await gate.refresh(kernel: kernel)
        }
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [ensureProvider(kernel: kernel)]
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("StepFun", bundle: .module),
                      systemImage: "step")
                    .font(.headline)
                Text(LumiPluginLocalization.string("LLM provider for chat and agent conversations.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
}