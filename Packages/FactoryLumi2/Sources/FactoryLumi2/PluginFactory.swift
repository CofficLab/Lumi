import Foundation
import KernelCore
import PluginAppIconDesigner
import PluginDevice
import PluginLogoCoffic
import PluginSettingGeneral
import PluginThemePack
import PluginToolbarSettings
import PluginVideoConverter
import PluginWhiteNoise

/// 产出各种插件的工厂协议。
///
/// 集中管理插件的构造；`KernelFactory.makeKernel` 通过它产出插件并
/// 用 `kernel.start(plugins:)` 启动。宿主可实现该协议覆盖插件列表。
@MainActor
public protocol PluginFactory {
    /// 产出要启动的全部插件。
    ///
    /// 各插件在 `onBoot` 中解析内核已有 Provider 并注册自己的贡献
    /// （如 SettingGeneralPlugin 注册「通用」入口、DevicePlugin 注册
    ///  「设备信息」入口与主内容、SettingsToolbarPlugin 注册工具栏设置按钮）。
    func makePlugins() -> [any SuperPlugin]
}

/// 默认 `PluginFactory` 实现：产出默认插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    /// 产出默认插件列表。
    public func makePlugins() -> [any SuperPlugin] {
        [
            SettingGeneralPlugin(),
            DevicePlugin(),
            AppIconDesignerPlugin(),
            LogoCofficPlugin(),
            SettingsToolbarPlugin(),
            ThemePackPlugin(),
            VideoConverterPlugin(),
            WhiteNoisePlugin(),
        ]
    }
}
