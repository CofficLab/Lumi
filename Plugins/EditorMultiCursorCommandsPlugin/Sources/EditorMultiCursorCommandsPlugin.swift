import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// 多光标命令编辑器插件：添加多光标编辑的上下文菜单操作
public enum EditorMultiCursorCommandsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "cursorarrow.and.square.on.square.dashed"

    public static let info = LumiPluginInfo(
        id: "EditorMultiCursorCommands",
        displayName: LumiPluginLocalization.string("Multi-Cursor Commands", bundle: .module),
        description: LumiPluginLocalization.string("Adds context menu actions for multi-cursor editing (add next occurrence, select all, clear).", bundle: .module),
        order: 13
    )
}
