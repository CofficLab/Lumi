import LumiCoreKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

/// 文件树 V2 插件
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
public enum EditorFileTreeV2Plugin: LumiPlugin, SuperLog {

    /// 是否启用 Git 状态显示功能（禁用可提升文件树滚动性能）。
    public static let gitStatusEnabled: Bool = true

    /// 是否启用文件树行拖拽和目录 drop target。
    public static let dragAndDropEnabled: Bool = true

    /// 是否启用定位文件时的闪烁高亮。
    public static let flashHighlightEnabled: Bool = true

    // MARK: - SuperLog Configuration

    public static let emoji = "🌲"
    public static let verbose: Bool = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-file-tree-v2",
        displayName: LumiPluginLocalization.string("Editor File Tree V2", bundle: .module),
        description: LumiPluginLocalization.string("Native rendering file tree using NSCollectionView for better performance.", bundle: .module),
        order: 0,
        category: .development,
        policy: .alwaysOn,
        stage: .dev,
        iconName: "square.grid.2x2.fill",
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        guard context.showsRail else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "explorer-v2",
                order: info.order,
                title: LumiPluginLocalization.string("Explorer V2", bundle: .module),
                systemImage: iconName
            ) {
                TreeViewV2(lumiCore: lumiCore)
            }
        ]
    }
}
