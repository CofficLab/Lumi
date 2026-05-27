import SwiftUI
import os
import DeviceMonitorKit
import LumiCoreKit
import SuperLogKit

public actor DeviceInfoPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "💻"
    public static var category: PluginCategory { .general }
    public nonisolated static let enable: Bool = true
    public nonisolated static let verbose: Bool = true

    public static let id: String = "DeviceInfo"
    public static let navigationId: String = "device_info"
    public static let displayName: String = PluginDeviceInfoLocalization.string("Device Info")
    public static let description: String = PluginDeviceInfoLocalization.string("Show system status like CPU, Memory, Disk, Battery, etc.")
    public static let iconName = "macbook.and.iphone"
    public static let isConfigurable: Bool = false
    public static var order: Int { 10 }

    // MARK: - Instance

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = DeviceInfoPlugin()

    private init() {}

    public nonisolated func onEnable() {
        Task { @MainActor in
            CPUHistoryService.shared.startRecording()
            MemoryHistoryService.shared.startRecording()
        }
    }

    public nonisolated func onDisable() {
        Task { @MainActor in
            CPUHistoryService.shared.stopRecording()
            MemoryHistoryService.shared.stopRecording()
        }
    }

    // MARK: - UI Contributions

    @MainActor
    public func addMenuBarContentView() -> AnyView? {
        AnyView(DeviceInfoMenuBarContentView())
    }

    @MainActor
    public func addMenuBarPopupViews() -> [AnyView] {
        [
            AnyView(DeviceInfoMenuBarPopupView()),
            AnyView(MemoryMenuBarPopupView()),
        ]
    }

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(DeviceInfoView())
        }
    }
}

enum PluginDeviceInfoLocalization {
    static let table = "DeviceInfo"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
