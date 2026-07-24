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

    /// 清空所有插件贡献(供全量重建使用)。
    /// 默认 no-op;支持运行时启停的实现应覆盖。
    func clearAllContributions()
}

public extension SettingsProviding {
    func clearAllContributions() {}
}
