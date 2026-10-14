import ProviderUninstall

/// 通用设置页需要的最小卸载能力。
@MainActor
protocol GeneralSettingsUninstallCapability: AnyObject {
    var isUninstallAvailable: Bool { get }
    func scanUninstall() async -> UninstallScan
    func prepareForUninstall() async
    func uninstall(options: UninstallOptions) async throws -> UninstallResult
}

/// 默认实现：把 `UninstallProviding` 与内核停机闭包收窄为本插件的卸载能力。
@MainActor
final class GeneralSettingsUninstallCapabilityAdapter: GeneralSettingsUninstallCapability {
    private let uninstallProvider: (any UninstallProviding)?
    private let prepareForUninstall: (@MainActor () async -> Void)?

    init(
        uninstallProvider: (any UninstallProviding)?,
        prepareForUninstall: (@MainActor () async -> Void)?
    ) {
        self.uninstallProvider = uninstallProvider
        self.prepareForUninstall = prepareForUninstall
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
}