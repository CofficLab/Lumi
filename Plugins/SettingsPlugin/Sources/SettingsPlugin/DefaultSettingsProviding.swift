import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Settings Provider

/// 默认设置服务实现
///
/// 负责管理所有插件的设置标签项和 LLM 提供商设置项的注册和查询。
///
/// 已发布 (`@Published`) — `LumiKernelContainer.subscribeToObjectWillChange`
/// 会把本服务的 `objectWillChange` 转发到 kernel,从而让
/// `@ObservedObject var kernel: LumiKernel` 的宿主 UI 在 register/unregister
/// 后自动重渲染。
@MainActor
public final class DefaultSettingsProviding: SettingsProviding {
    @Published public private(set) var allSettingsTabItems: [SettingsTabItem] = []
    @Published public private(set) var allLLMProviderSettingsItems: [LLMProviderSettingsItem] = []

    private var settingsTabItems: [String: SettingsTabItem] = [:]
    private var settingsTabOrder: [String] = []
    private var llmProviderSettingsItems: [String: LLMProviderSettingsItem] = [:]
    private var llmProviderSettingsOrder: [String] = []

    @Published public private(set) var allSettingsSections: [SettingsSection] = []
    private var settingsSections: [String: SettingsSection] = [:]
    private var settingsSectionOrder: [String] = []

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

    public func registerSettingsSection(_ section: SettingsSection) {
        if settingsSections[section.id] == nil {
            settingsSectionOrder.append(section.id)
        }
        settingsSections[section.id] = section
        updateSortedSettingsSections()
    }

    public func unregisterSettingsSection(id: String) {
        settingsSections.removeValue(forKey: id)
        settingsSectionOrder.removeAll { $0 == id }
        updateSortedSettingsSections()
    }

    public func clearAllContributions() {
        settingsTabItems.removeAll()
        settingsTabOrder.removeAll()
        llmProviderSettingsItems.removeAll()
        llmProviderSettingsOrder.removeAll()
        settingsSections.removeAll()
        settingsSectionOrder.removeAll()
        updateSortedSettingsTabs()
        updateSortedLLMProviderSettings()
        updateSortedSettingsSections()
    }

    private func updateSortedSettingsTabs() {
        allSettingsTabItems = settingsTabOrder.compactMap { settingsTabItems[$0] }
    }

    private func updateSortedLLMProviderSettings() {
        allLLMProviderSettingsItems = llmProviderSettingsOrder.compactMap { llmProviderSettingsItems[$0] }
    }

    private func updateSortedSettingsSections() {
        allSettingsSections = settingsSectionOrder.compactMap { settingsSections[$0] }
    }
}
