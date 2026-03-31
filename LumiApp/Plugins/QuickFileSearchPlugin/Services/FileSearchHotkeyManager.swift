import AppKit
import Combine
import Foundation
import SwiftUI
import os

/// 文件搜索热键管理器
///
/// 负责监听全局快捷键 Cmd+P，控制搜索框的显示/隐藏状态
@MainActor
final class FileSearchHotkeyManager: ObservableObject {
    static let shared = FileSearchHotkeyManager()

    // MARK: - Published Properties

    /// 搜索框是否可见
    @Published private(set) var isOverlayVisible: Bool = false

    // MARK: - Private Properties

    private var eventMonitor: Any?

    private init() {}

    // MARK: - Public Methods

    /// 开始监听快捷键
    func startMonitoring() {
        guard eventMonitor == nil else {
            return
        }

        // 监听应用内的键盘事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            
            let result = self.handleKeyEvent(event)
            
            return result
        }
    }

    /// 停止监听快捷键
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// 显示搜索框
    func showOverlay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isOverlayVisible = true
        }
    }

    /// 隐藏搜索框
    func hideOverlay() {
        withAnimation(.easeOut(duration: 0.2)) {
            isOverlayVisible = false
        }
    }

    /// 切换搜索框显示状态
    func toggleOverlay() {
        if self.isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    // MARK: - Private Methods

    /// 处理键盘事件
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        // Cmd+P (keyCode 35)
        if event.keyCode == 35 && event.modifierFlags.contains(.command) {
            // 只有 Cmd 键，没有其他修饰键
            let hasOnlyCommand = !event.modifierFlags.contains(.shift) &&
                                  !event.modifierFlags.contains(.control) &&
                                  !event.modifierFlags.contains(.option)

            if hasOnlyCommand {
                Task { @MainActor [weak self] in
                    self?.toggleOverlay()
                }
                
                return nil  // 消费事件，阻止默认行为
            }
        }

        // Esc 键关闭搜索框
        if event.keyCode == 53 && self.isOverlayVisible {
            Task { @MainActor [weak self] in
                self?.hideOverlay()
            }
            return nil
        }

        return event
    }
}
