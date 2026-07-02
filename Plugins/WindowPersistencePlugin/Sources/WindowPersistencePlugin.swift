import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI
import os

/// 窗口持久化插件：监听各窗口 VM 状态变化，防抖保存到磁盘（项目、会话、面板、编辑器等）。
public enum WindowPersistencePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "macwindow"

    public static let info = LumiPluginInfo(
        id: "WindowPersistence",
        displayName: LumiPluginLocalization.string("Window Persistence", bundle: .module),
        description: LumiPluginLocalization.string("Save window states when they change", bundle: .module),
        order: 999
    )
}
