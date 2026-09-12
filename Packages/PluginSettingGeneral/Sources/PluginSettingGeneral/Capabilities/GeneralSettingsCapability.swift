import Foundation
import ProviderAppUpdate
import ProviderDiagnostics
import ProviderDocsView
import ProviderOnboarding
import ProviderUninstall

/// 通用设置页需要的最小外部操作集合。
///
/// 收敛 `DocsViewProviding` / `DiagnosticsProviding` /
/// `AppUpdateChannelProviding` / `OnboardingProviding` /
/// `UninstallProviding` 五个 Provider，View 与 ViewModel 都不再直接接触 Provider。
@MainActor
protocol GeneralSettingsCapability {
    /// 所有提供了说明书的文档条目。
    var manuals: [DocsEntry] { get }

    // MARK: 更新通道

    var updateChannel: AppUpdateChannel { get }
    var isUpdateChannelAvailable: Bool { get }
    func setUpdateChannel(_ channel: AppUpdateChannel)

    // MARK: 新手引导

    var isOnboardingAvailable: Bool { get }
    func replayOnboarding()

    // MARK: 诊断

    var isDiagnosticsAvailable: Bool { get }
    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive

    // MARK: 卸载

    var isUninstallAvailable: Bool { get }
    func scanUninstall() async -> UninstallScan
    func prepareForUninstall() async
    func uninstall(options: UninstallOptions) async throws -> UninstallResult

    // MARK: 外部事件

    @discardableResult
    func addDocsViewObserver(
        _ callback: @escaping (DocsViewEvent) -> Void
    ) -> (any DocsViewObserverHandle)?
}

/// 默认实现：持有各 Provider，把最小操作转发给它们。
@MainActor
final class GeneralSettingsCapabilityAdapter: GeneralSettingsCapability {
    private let docsProvider: (any DocsViewProviding)?
    private let diagnosticsProvider: (any DiagnosticsProviding)?
    private let updateProvider: (any AppUpdateChannelProviding)?
    private let onboardingProvider: (any OnboardingProviding)?
    private let uninstallProvider: (any UninstallProviding)?
    private let prepareForUninstall: (@MainActor () async -> Void)?

    init(
        docsProvider: (any DocsViewProviding)?,
        diagnosticsProvider: (any DiagnosticsProviding)?,
        updateProvider: (any AppUpdateChannelProviding)?,
        onboardingProvider: (any OnboardingProviding)?,
        uninstallProvider: (any UninstallProviding)?,
        prepareForUninstall: (@MainActor () async -> Void)?
    ) {
        self.docsProvider = docsProvider
        self.diagnosticsProvider = diagnosticsProvider
        self.updateProvider = updateProvider
        self.onboardingProvider = onboardingProvider
        self.uninstallProvider = uninstallProvider
        self.prepareForUninstall = prepareForUninstall
    }

    var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    var updateChannel: AppUpdateChannel {
        updateProvider?.channel ?? .stable
    }

    var isUpdateChannelAvailable: Bool {
        updateProvider != nil
    }

    func setUpdateChannel(_ channel: AppUpdateChannel) {
        updateProvider?.setChannel(channel)
    }

    var isOnboardingAvailable: Bool {
        onboardingProvider != nil
    }

    func replayOnboarding() {
        onboardingProvider?.replay()
    }

    var isDiagnosticsAvailable: Bool {
        diagnosticsProvider != nil
    }

    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive {
        guard let diagnosticsProvider else {
            throw GeneralSettingsCapabilityError.unavailable("诊断日志服务暂不可用。")
        }
        return try await diagnosticsProvider.makeDiagnosticsArchive()
    }

    var isUninstallAvailable: Bool {
        uninstallProvider != nil
    }

    func scanUninstall() async -> UninstallScan {
        await uninstallProvider?.scan() ?? UninstallScan()
    }

    func prepareForUninstall() async {
        await prepareForUninstall?()
    }

    func uninstall(options: UninstallOptions) async throws -> UninstallResult {
        guard let uninstallProvider else {
            throw GeneralSettingsCapabilityError.unavailable("卸载服务暂不可用。")
        }
        return try await uninstallProvider.uninstall(options: options)
    }

    @discardableResult
    func addDocsViewObserver(
        _ callback: @escaping (DocsViewEvent) -> Void
    ) -> (any DocsViewObserverHandle)? {
        docsProvider?.addDocsViewObserver(callback)
    }
}

/// Capability 抛出的服务不可用错误。
enum GeneralSettingsCapabilityError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        }
    }
}
