import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Settings Provider

/// 默认设置服务实现
///
/// 负责管理所有插件的设置标签项和 LLM 提供商设置项的注册和查询。
@MainActor
public final class DefaultSettingsProviding: SettingsProviding {
    public private(set) var allSettingsTabItems: [SettingsTabItem] = []
    public private(set) var allLLMProviderSettingsItems: [LLMProviderSettingsItem] = []

    private var settingsTabItems: [String: SettingsTabItem] = [:]
    private var settingsTabOrder: [String] = []
    private var llmProviderSettingsItems: [String: LLMProviderSettingsItem] = [:]
    private var llmProviderSettingsOrder: [String] = []

    public init() {}

    public func registerSettingsTabItem(_ item: SettingsTabItem) {
        if settingsTabItems[item.id] == nil {
            settingsTabOrder.append(item.id)
        }
        settingsTabItems[item.id] = item
        updateSortedSettingsTabs()
    }

    public func unregisterSettingsTabItem(id: String) {
        settingsTabItems.removeValue(forKey: id)
        settingsTabOrder.removeAll { $0 == id }
        updateSortedSettingsTabs()
    }

    public func registerLLMProviderSettingsItem(_ item: LLMProviderSettingsItem) {
        if llmProviderSettingsItems[item.providerID] == nil {
            llmProviderSettingsOrder.append(item.providerID)
        }
        llmProviderSettingsItems[item.providerID] = item
        updateSortedLLMProviderSettings()
    }

    public func unregisterLLMProviderSettingsItem(providerID: String) {
        llmProviderSettingsItems.removeValue(forKey: providerID)
        llmProviderSettingsOrder.removeAll { $0 == providerID }
        updateSortedLLMProviderSettings()
    }

    private func updateSortedSettingsTabs() {
        allSettingsTabItems = settingsTabOrder.compactMap { settingsTabItems[$0] }
    }

    private func updateSortedLLMProviderSettings() {
        allLLMProviderSettingsItems = llmProviderSettingsOrder.compactMap { llmProviderSettingsItems[$0] }
    }
}
