import Combine
import SwiftUI

/// 窗口管理命令
///
/// 提供多窗口管理相关的菜单命令
/// 使用 CommandGroup 插入到系统自带的窗口菜单中，避免重复创建"窗口"菜单
@MainActor
struct WindowCommands: Commands {
    var body: some Commands {
        // 在系统自带的"窗口"菜单中添加自定义命令
        CommandGroup(after: .windowArrangement) {
            Divider()

            // 窗口列表
            WindowListSection()

            Divider()

            // 窗口导航
            Button("显示下一个窗口") {
                Task { @MainActor in
                    WindowCommands.selectNextWindow()
                }
            }
            .keyboardShortcut("`", modifiers: [.command])

            Button("显示上一个窗口") {
                Task { @MainActor in
                    WindowCommands.selectPreviousWindow()
                }
            }
            .keyboardShortcut("`", modifiers: [.command, .shift])
        }
    }

    // MARK: - Static Methods

    /// 新建窗口
    static func newWindow() {
        Task { @MainActor in
            WindowManager.shared.openNewWindow()
        }
    }

    /// 关闭当前窗口
    static func closeCurrentWindow() {
        Task { @MainActor in
            guard let windowId = WindowManager.shared.activeWindowId else { return }
            WindowManager.shared.closeWindow(windowId)
        }
    }

    /// 切换到下一个窗口
    static func selectNextWindow() {
        Task { @MainActor in
            let manager = WindowManager.shared
            guard let currentId = manager.activeWindowId,
                  let currentIndex = manager.windowStates.firstIndex(where: { $0.id == currentId }) else { return }

            let nextIndex = (currentIndex + 1) % manager.windowStates.count
            let nextWindow = manager.windowStates[nextIndex]
            manager.activateWindow(nextWindow.id)
        }
    }

    /// 切换到上一个窗口
    static func selectPreviousWindow() {
        Task { @MainActor in
            let manager = WindowManager.shared
            guard let currentId = manager.activeWindowId,
                  let currentIndex = manager.windowStates.firstIndex(where: { $0.id == currentId }) else { return }

            let previousIndex = (currentIndex - 1 + manager.windowStates.count) % manager.windowStates.count
            let previousWindow = manager.windowStates[previousIndex]
            manager.activateWindow(previousWindow.id)
        }
    }
}

// MARK: - Window List Section

/// 窗口列表部分
@MainActor
struct WindowListSection: View {
    @ObservedObject private var windowManager = WindowManager.shared

    var body: some View {
        ForEach(windowManager.windowStates) { state in
            Button(state.title) {
                windowManager.activateWindow(state.id)
            }
            .keyboardShortcut(
                windowManager.windowStates.firstIndex(where: { $0.id == state.id }).map {
                    KeyEquivalent(Character(String($0 + 1)))
                } ?? .init("0"),
                modifiers: [.command]
            )
        }
    }
}
