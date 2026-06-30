import LumiCoreKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

public enum EditorFileTreePanelPlugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "folder"

    /// 是否启用 Git 状态显示功能（禁用可提升文件树滚动性能）
    public static let gitStatusEnabled: Bool = false

    // MARK: - SuperLog Configuration

    public static let emoji = "🌳"
    public static let verbose: Bool = true
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-file-tree",
        displayName: LumiPluginLocalization.string("Editor File Tree", bundle: .module),
        description: LumiPluginLocalization.string("Explorer tab in the editor rail.", bundle: .module),
        order: 0
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail,
              context.activeSectionID == LumiEditorPanelContainer.id
        else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "explorer",
                order: info.order,
                title: LumiPluginLocalization.string("Explorer", bundle: .module),
                systemImage: iconName
            ) {
                TreeView()
            }
        ]
    }
}
