import Foundation
import SwiftUI
import AppKit

/// 设备信息插件：展示当前设备的详细信息
actor DeviceInfoPlugin: SuperPlugin {
    // MARK: - Plugin Properties
    
    static var id: String = "DeviceInfoPlugin"
    static var displayName: String = "设备信息"
    static var description: String = "展示 CPU、内存、磁盘、电池等系统状态"
    static var iconName: String = "macbook.and.iphone"
    static var isConfigurable: Bool = false
    static var order: Int { 10 }
    
    // MARK: - Instance
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = DeviceInfoPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "\(Self.id).dashboard",
                title: "设备概览",
                icon: "macbook.and.iphone",
                pluginId: Self.id
            ) {
                DeviceInfoView()
            }
        ]
    }
    
    @MainActor func addStatusBarMenuItems() -> [NSMenuItem]? {
        let item = NSMenuItem(title: "设备概览", action: #selector(Helper.showDeviceWindow), keyEquivalent: "")
        item.target = Helper.shared
        return [item]
    }
}

// Helper for Obj-C selector target
private class Helper: NSObject {
    static let shared = Helper()
    
    @objc func showDeviceWindow() {
        // Simple window presentation logic
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "设备概览"
        window.contentView = NSHostingView(rootView: DeviceInfoView())
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
    }
}
