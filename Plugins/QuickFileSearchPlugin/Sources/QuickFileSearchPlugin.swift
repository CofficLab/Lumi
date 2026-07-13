import EditorService
import Foundation
import LumiCoreKit
import SwiftUI

public enum QuickFileSearchBridge {
    public nonisolated(unsafe) static var activeWindowIdProvider: (@MainActor () -> UUID?)?
    public nonisolated(unsafe) static var selectFileHandler: (@MainActor (String, UUID?) -> Void)?
}

/// Quick File Search Plugin: 快速文件搜索插件
///
/// 功能：通过 Cmd+P 快捷键触发悬浮文件搜索框，快速定位和选择项目中的文件
public enum QuickFileSearchPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "magnifyingglass"

    public static let info = LumiPluginInfo(
        id: "QuickFileSearch",
        displayName: LumiPluginLocalization.string("Quick File Search", bundle: .module),
        description: LumiPluginLocalization.string("Fast file search with Cmd+P", bundle: .module),
        order: 50
    )

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        configureBridge(context: context)
        let projectPathProvider = {
            context.lumiCore?.projectState?.currentProject?.path ?? ""
        }
        let windowIdProvider = {
            context.resolve(LumiEditorServicing.self)?.editorService.state.windowId
        }
        return [
            LumiRootOverlayItem(id: "\(info.id).overlay", order: info.order) { content in
                AnyView(
                    FileSearchOverlay(
                        content: content,
                        projectPathProvider: projectPathProvider,
                        windowIdProvider: windowIdProvider
                    )
                )
            }
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        let projectPath = context.lumiCore?.projectState?.currentProject?.path ?? ""
        return AnyView(QuickFileSearchSettingsView(projectPath: projectPath))
    }

    @MainActor
    private static func configureBridge(context: LumiPluginContext) {
        QuickFileSearchBridge.activeWindowIdProvider = {
            context.resolve(LumiEditorServicing.self)?.editorService.state.windowId
        }
        QuickFileSearchBridge.selectFileHandler = { path, _ in
            guard let editor = context.resolve(LumiEditorServicing.self) else { return }
            editor.editorService.sessions.open(at: URL(fileURLWithPath: path))
        }
    }
}
