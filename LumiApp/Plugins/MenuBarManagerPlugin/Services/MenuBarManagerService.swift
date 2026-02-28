import AppKit
import ApplicationServices
import Combine
import SwiftUI
import OSLog
import MagicKit

/// 菜单栏管理服务
/// 负责获取和管理菜单栏图标
@MainActor
class MenuBarManagerService: ObservableObject, SuperLog {
    static let shared = MenuBarManagerService()
    
    // MARK: - Published Properties
    
    /// 是否已获得辅助功能权限
    @Published var isPermissionGranted: Bool = false
    
    /// 菜单栏项列表 (模拟/实际获取)
    @Published var menuBarItems: [MenuBarItem] = []
    
    /// 隐藏的菜单栏项
    @Published var hiddenItems: Set<String> = []
    
    // MARK: - Private Properties
    
    private var monitor: Any?
    
    // MARK: - Initialization
    
    private init() {
        checkPermission()
        // 恢复保存的设置
        loadSettings()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 检查辅助功能权限
    func checkPermission() {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        isPermissionGranted = AXIsProcessTrustedWithOptions(options)
        
        if isPermissionGranted {
            refreshMenuBarItems()
        }
    }
    
    /// 请求权限
    func requestPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    /// 刷新菜单栏项
    func refreshMenuBarItems() {
        guard isPermissionGranted else { return }
        
        Task.detached(priority: .userInitiated) {
            let items = await self.fetchMenuBarItems()
            await MainActor.run {
                self.menuBarItems = items
            }
        }
    }
    
    /// 切换项目的隐藏状态
    func toggleItemVisibility(id: String) {
        if hiddenItems.contains(id) {
            hiddenItems.remove(id)
        } else {
            hiddenItems.insert(id)
        }
        saveSettings()
        // 这里应该触发实际的隐藏/显示逻辑
        updateMenuBarVisibility()
    }
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        // 监听鼠标移动，用于实现"鼠标悬停显示隐藏项"的功能
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
        }
    }
    
    private func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func handleMouseMove(_ event: NSEvent) {
        // 获取鼠标位置（屏幕坐标，左下角为原点）
        let location = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let menuBarHeight: CGFloat = 24 // 标准菜单栏高度，刘海屏可能不同
        
        // 检查是否在菜单栏区域
        if location.y > screenHeight - menuBarHeight {
            // 鼠标在菜单栏上
            // 这里可以触发"显示隐藏项"的逻辑
            // os_log("Mouse over menu bar")
        }
    }
    
    private func updateMenuBarVisibility() {
        // 实际应用中，这里需要通过 AXUIElement 或覆盖窗口来隐藏/显示图标
        // 由于这涉及复杂的系统交互，此处仅为逻辑演示
    }

    
    /// 获取菜单栏项的具体实现
    private func fetchMenuBarItems() async -> [MenuBarItem] {
        // 这里需要通过 AXUIElement 获取系统菜单栏项
        // 由于这是一个复杂的操作，且依赖于系统版本，这里先做一个简化的实现框架
        // 实际实现需要遍历 SystemUIServer 或 ControlCenter 的 AX 树
        
        var items: [MenuBarItem] = []
        
        // 1. 获取 Control Center (macOS 11+)
        let systemWide = AXUIElementCreateSystemWide()
        
        // 这是一个简化的逻辑，实际上需要更复杂的遍历
        // 为了演示，我们先添加一些模拟数据或者尝试获取最顶层的应用
        
        // 尝试获取正在运行的应用作为"菜单栏项"的代理（实际上每个应用都有菜单栏图标）
        // 真正的菜单栏管理工具是通过 AX 获取 MenuBar 上的 Item
        
        // 模拟数据用于展示 UI
        /*
        items = [
            MenuBarItem(id: "com.apple.controlcenter", name: "Control Center", icon: nil),
            MenuBarItem(id: "com.apple.siri", name: "Siri", icon: nil),
            MenuBarItem(id: "com.apple.spotlight", name: "Spotlight", icon: nil)
        ]
         */
        
        // 尝试使用 CGWindowList 获取状态栏窗口
        if let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for info in windowInfoList {
                if let layer = info[kCGWindowLayer as String] as? Int, layer == 25 { // 25 is kCGStatusWindowLevel
                    if let ownerName = info[kCGWindowOwnerName as String] as? String,
                       let ownerPID = info[kCGWindowOwnerPID as String] as? Int {
                        let id = "\(ownerName)-\(ownerPID)"
                        items.append(MenuBarItem(id: id, name: ownerName, icon: nil))
                    }
                }
            }
        }
        
        return items
    }
    
    private func saveSettings() {
        // 保存 hiddenItems 到 UserDefaults
        UserDefaults.standard.set(Array(hiddenItems), forKey: "MenuBarManager_HiddenItems")
    }
    
    private func loadSettings() {
        if let saved = UserDefaults.standard.array(forKey: "MenuBarManager_HiddenItems") as? [String] {
            hiddenItems = Set(saved)
        }
    }
}

/// 菜单栏项模型
struct MenuBarItem: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: NSImage?
    
    static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.id == rhs.id
    }
}
