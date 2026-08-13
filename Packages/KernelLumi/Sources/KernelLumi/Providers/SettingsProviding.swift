import Foundation
import SwiftUI

/// 设置能力协议
///
/// 定义 LumiCore 需要的设置管理功能，由具体布局插件实现。
/// 负责管理设置标签项和 LLM 提供商设置项的注册和查询。
@MainActor
public protocol SettingsProviding: ObservableObject {
    /// 所有已注册的设置标签项（按注册顺序）
    var allSettingsTabItems: [SettingsTabItem] { get }

    /// 所有已注册的 LLM 提供商设置项（按注册顺序）
    var allLLMProviderSettingsItems: [LLMProviderSettingsItem] { get }

    /// 注册设置标签项
    func registerSettingsTabItem(_ item: SettingsTabItem)

    /// 注销设置标签项
    func unregisterSettingsTabItem(id: String)

    /// 注册 LLM 提供商设置项
    func registerLLMProviderSettingsItem(_ item: LLMProviderSettingsItem)

    /// 注销 LLM 提供商设置项
    func unregisterLLMProviderSettingsItem(providerID: String)

    /// 所有已注册的设置 section 项（按注册顺序）
    var allSettingsSections: [SettingsSection] { get }

    /// 注册设置 section 项（挂载到指定 tab 的内容区）
    func registerSettingsSection(_ section: SettingsSection)

    /// 注销设置 section 项
    func unregisterSettingsSection(id: String)

    /// 清空所有插件贡献(供全量重建使用)。
    /// 默认 no-op;支持运行时启停的实现应覆盖。
    func clearAllContributions()
}

public extension SettingsProviding {
    func clearAllContributions() {}

    /// 查询挂载到指定 tab 的所有 section（按注册顺序）。
    /// 消费侧通常再按 `order` 升序排序后渲染。
    func settingsSections(forTabID tabID: String) -> [SettingsSection] {
        allSettingsSections.filter { $0.tabID == tabID }
    }
}
