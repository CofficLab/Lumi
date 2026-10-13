import ProviderAppUpdate

/// 通用设置页需要的最小更新通道能力。
@MainActor
protocol GeneralSettingsUpdateChannelCapability: AnyObject {
    var updateChannel: AppUpdateChannel { get }
    var isUpdateChannelAvailable: Bool { get }
    func setUpdateChannel(_ channel: AppUpdateChannel)
}

/// 默认实现：把 `AppUpdateChannelProviding` 收窄为本插件的更新通道能力。
@MainActor
final class GeneralSettingsUpdateChannelCapabilityAdapter: GeneralSettingsUpdateChannelCapability {
    private let updateProvider: (any AppUpdateChannelProviding)?

    init(updateProvider: (any AppUpdateChannelProviding)?) {
        self.updateProvider = updateProvider
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
}