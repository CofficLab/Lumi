import MagicKit
import SwiftUI
import os

actor DeviceInfoPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "DeviceInfo"
    static let navigationId: String = "device_info"
    static let displayName: String = String(localized: "Device Info", table: "DeviceInfo")
    static let description: String = String(localized: "Show system status like CPU, Memory, Disk, Battery, etc.", table: "DeviceInfo")
    static let iconName: String = "macbook.and.iphone"
    static let isConfigurable: Bool = false
    static var order: Int { 10 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = DeviceInfoPlugin()

    init() {
        Task { @MainActor in
            CPUHistoryService.shared.startRecording()
            _ = MemoryHistoryService.shared
        }
    }

    // MARK: - UI Contributions

    @MainActor
    func addStatusBarContentView() -> AnyView? {
        AnyView(DeviceInfoStatusBarContentView())
    }

    @MainActor
    func addStatusBarPopupViews() -> [AnyView] {
        [
            AnyView(DeviceInfoStatusBarPopupView()),
            AnyView(MemoryStatusBarPopupView()),
        ]
    }

    @MainActor
    func addPanelView() -> AnyView? {
        AnyView(DeviceInfoView())
    }

    /// 该面板不需要右侧栏
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
