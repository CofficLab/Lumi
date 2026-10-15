#if DEBUG
import Foundation
import os
import KernelCore
import ProviderLLMManager
import KitLLM
import LumiLoggingKit

/// UI 测试专用供应商的装配插件（仅 DEBUG）。
///
/// ## 双重 gate
///
/// 类体整体包在 `#if DEBUG` 里，Release 构建中**本插件根本不存在**——不会有假
/// 供应商混进用户的发布包，也不需要在 UI 里做任何隐藏逻辑。
///
/// 运行时再叠一层启动参数 gate：只有 App 以 `--lumi-ui-testing` 启动时才注册。
/// 也就是说开发者日常 Debug 运行时看不到这个供应商，只有 UI 测试会用到。
///
/// ## 选中态处理
///
/// UI 测试需要一个**确定的**供应商，而不是「用户上次选的那个」。因此本插件在
/// 注册后强制选中 `ui-test`：
///
/// - `CustomLLMManager` 的选中态持久化在 `UserDefaults.standard`，而
///   `--lumi-ui-testing-isolated-storage` 只隔离了数据目录，**不隔离 UserDefaults**。
///   不强制选中就会拿到上一次真实运行残留的供应商，转头发起真实网络请求。
/// - 强制选中之后，后续其他供应商插件注册时的 `ensureValidSelection` 不会覆盖它
///   （选中值有效即保留）。
/// - 反向污染由 `clearStaleSelection()` 兜底：非测试启动时若发现选中态还指向
///   `ui-test`，主动清除，避免它残留在真实运行的 UserDefaults 里。
///
/// ## 需要特定场景怎么办
///
/// 不要新增启动参数。用模型选择器切到对应模型即可——`ui-test-error`、`ui-test-tool`
/// 等都是本供应商的模型。这样测试之间无需各自重启出不同配置。
@MainActor
public final class PluginUITestProvider: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.llm-provider.uitest",
        category: "UITest"
    )
    nonisolated public static let emoji = "🧪"
    nonisolated static let verbose = false

    /// 启用本夹具的启动参数。
    public static let launchArgument = "--lumi-ui-testing"

    public static let pluginID = "com.coffic.lumi.plugin.llm-provider.uitest"

    public let id = PluginUITestProvider.pluginID
    /// 排在其他供应商之后注册，让本插件的强制选中成为最后生效的那次。
    public let order = 900
    public let metadata = PluginMetadata(
        id: PluginUITestProvider.pluginID,
        name: "UI Test Provider",
        description: "Deterministic LLM provider for UI tests (DEBUG only)",
        category: .llm,
        stage: .experimental,
        // `.alwaysOn`，而不是 `.disabled`。
        //
        // - Important: 内核在启动时会**无条件**剔除 `policy == .disabled` 的插件
        //   （见 `KernelCore+Plugin.swift` 的 `activePlugins` 过滤），这类插件
        //   根本不进入 boot 流程，`onBoot` 里的 `--lumi-ui-testing` 判断因此
        //   永远不会执行——表现为所有 `--lumi-ui-testing` 的 UI 测试都拿不到
        //   本供应商（模型选择器里没有 UI Test）。
        // - 这里真正承担 gate 职责的是 `onBoot` 开头的 `Self.isEnabled` 判断：
        //   只有以 `--lumi-ui-testing` 启动时才注册供应商，否则直接 return。
        //   叠加类体的 `#if DEBUG`，Release 构建中本插件不存在。
        // - 因此 `.alwaysOn` 不会让假供应商泄漏到日常运行或发布包。
        policy: .alwaysOn
    )

    public init() {}

    /// 是否处于 UI 测试模式。
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    // MARK: - 生命周期

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard Self.isEnabled else {
            clearStaleSelection(kernel: kernel)
            return
        }
        guard let manager = kernel.resolveProvider((any LLMManaging).self) else {
            Self.logger.error("\(Self.t)LLMManaging not resolved, UI test provider skipped")
            return
        }

        // 桩注入在传输层：VendorLLMProvider / OpenAI 适配器 / SSE 解析全部是真实代码。
        let provider = UITestProvider(
            apiService: VendorAPIService(networkProvider: UITestStubNetwork())
        )
        try manager.register(provider)

        // 强制选中，使回合确定性路由到桩。不强制就会用 UserDefaults 里
        // 上一次真实运行残留的供应商（UserDefaults 不在隔离存储范围内）。
        manager.select(
            providerID: UITestProvider.providerID,
            model: UITestScenario.defaultModel.rawValue,
            reason: .providerChanged
        )

        Self.logger.info(
            """
            \(Self.t)UI test provider registered and selected: \
            provider=\(UITestProvider.providerID, privacy: .public), \
            model=\(UITestScenario.defaultModel.rawValue, privacy: .public)
            """
        )
    }

    /// 清理上一次 UI 测试残留在 UserDefaults 里的选中态。
    ///
    /// `--lumi-ui-testing-isolated-storage` 只隔离数据目录，不隔离 UserDefaults。
    /// 一次 UI 测试会把选中态写成 `ui-test`；下次正常启动时本插件不注册，
    /// 选中态会悬空。虽然 `ensureValidSelection` 最终会回退到首个已注册供应商，
    /// 但在供应商注册完成前存在一段「选中态为空」的窗口，可能影响启动期 UI。
    /// 这里主动清除，避免这个窗口。
    private func clearStaleSelection(kernel: KernelCoreContainer) {
        guard let manager = kernel.resolveProvider((any LLMManaging).self),
              manager.selectedProviderID == UITestProvider.providerID,
              let stale = manager.selectedModelID else { return }
        Self.logger.info("\(Self.t)clearing stale UI test selection: \(stale.rawValue, privacy: .public)")
        // 重新选中首个可用供应商，语义上等价于「该选中态已失效」。
        if let fallback = manager.allProviders().first(where: { $0.providerInfo.id != UITestProvider.providerID }),
           let modelID = manager.modelID(providerID: fallback.providerInfo.id, model: nil) {
            manager.select(modelID: modelID, reason: .providerChanged)
        }
    }
}
#endif
