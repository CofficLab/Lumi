import LumiCoreKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

/// 文件树 V2 插件
///
/// 基于 NSCollectionView 的原生渲染实现，优化 LLM 流式响应期间的滚动性能。
/// 通过 nativeRenderingEnabled 开关控制是否启用原生渲染。
public enum EditorFileTreeV2Plugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .dev
    public static let category: LumiPluginCategory = .development
    public static let iconName = "square.grid.2x2.fill"

    /// 是否使用 NSCollectionView 原生渲染（关闭则使用 SwiftUI LazyVStack）
    public static let nativeRenderingEnabled: Bool = false

    /// 是否启用 Git 状态显示功能
    public static let gitStatusEnabled: Bool = true

    /// 是否显示 Swift Package Dependencies 区域
    public static let packageDependenciesEnabled: Bool = true

    /// 是否启用文件树行 hover 高亮
    public static let hoverHighlightEnabled: Bool = true

    /// 是否启用文件树行拖拽和目录 drop target
    public static let dragAndDropEnabled: Bool = true

    /// 是否启用右键菜单、重命名、新建、删除等上下文操作入口
    public static let contextMenuEnabled: Bool = true

    /// 是否显示缩进参考线
    public static let indentGuidesEnabled: Bool = true

    /// 是否启用定位文件时的闪烁高亮
    public static let flashHighlightEnabled: Bool = true

    /// 是否启用中键点击文件预览
    public static let middleClickPreviewEnabled: Bool = true

    /// 是否启用活动文件图标主题解析
    public static let activeFileIconThemeEnabled: Bool = true

    // MARK: - SuperLog Configuration

    public static let emoji = "🌲"
    public static let verbose: Bool = true
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree-v2")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-file-tree-v2",
        displayName: LumiPluginLocalization.string("Editor File Tree V2", bundle: .module),
        description: LumiPluginLocalization.string("Native rendering file tree using NSCollectionView for better performance.", bundle: .module),
        order: 0
    )

    @MainActor
    public static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail else { return [] }

        return [
            LumiPanelRailTabItem(
                id: "explorer-v2",
                order: info.order,
                title: LumiPluginLocalization.string("Explorer V2", bundle: .module),
                systemImage: iconName
            ) {
                TreeViewV2()
            }
        ]
    }
}
