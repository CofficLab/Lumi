import LumiCoreKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

public enum EditorFileTreePanelPlugin: LumiPlugin, SuperLog {

    /// 是否启用 Git 状态显示功能（禁用可提升文件树滚动性能）。
    public static let gitStatusEnabled: Bool = true

    /// 是否显示 Swift Package Dependencies 区域。
    public static let packageDependenciesEnabled: Bool = true

    /// 是否启用文件树行 hover 高亮。
    public static let hoverHighlightEnabled: Bool = true

    /// 是否启用文件树行拖拽和目录 drop target。
    public static let dragAndDropEnabled: Bool = true

    /// 是否启用右键菜单、重命名、新建、删除等上下文操作入口。
    public static let contextMenuEnabled: Bool = true

    /// 是否显示缩进参考线。
    public static let indentGuidesEnabled: Bool = true

    /// 是否启用定位文件时的闪烁高亮。
    public static let flashHighlightEnabled: Bool = true

    /// 是否启用中键点击文件预览。
    public static let middleClickPreviewEnabled: Bool = true

    /// 是否启用活动文件图标主题解析；关闭后只使用默认静态图标主题。
    public static let activeFileIconThemeEnabled: Bool = true

    // MARK: - SuperLog Configuration

    public static let emoji = "🌳"
    public static let verbose: Bool = true
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-rail-file-tree",
        displayName: LumiPluginLocalization.string("Editor File Tree", bundle: .module),
        description: LumiPluginLocalization.string("Explorer tab in the editor rail.", bundle: .module),
        order: 0,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "folder",
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "explorer",
                order: info.order,
                title: LumiPluginLocalization.string("Explorer", bundle: .module),
                systemImage: iconName
            ) {
                TreeView(lumiCore: lumiCore)
            }
        ]
    }
}
