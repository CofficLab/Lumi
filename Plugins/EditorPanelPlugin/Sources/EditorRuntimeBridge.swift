import EditorPreviewPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorTerminalPlugin
import LumiKernel
import LumiUI
import SwiftUI

/// 编辑器运行时桥接器
///
/// 将宿主装配的 `EditorService` 与 `LumiKernel` 注入到姊妹插件的静态 bridge 中,
/// 使 Preview / StickySymbolBar / BottomTerminal 等视图能在不直接持有内核的前提下
/// 取到编辑器服务、项目路径与主题。
///
/// 4.19.0 通过 `LumiCoreKit` 的 `PluginRuntimeContext` / `EditorLanguageRuntimeBridge`
/// 进行语言运行时引导;新版已移除该机制,这里仅做姊妹 bridge 的注入,
/// LSP / tree-sitter 等运行时由 `EditorService` 内部 facade 自行管理。
@MainActor
public enum EditorRuntimeBridge {
    /// 当前注入的编辑器服务(具象类型,便于姊妹 bridge 直接消费)。
    public private(set) static var editorService: EditorService?

    /// 当前注入的内核。
    public private(set) static var kernel: LumiKernel?

    /// 注入编辑器服务与内核,并把它们分发到姊妹 bridge。
    public static func configure(editorService: EditorService, kernel: LumiKernel) {
        self.editorService = editorService
        self.kernel = kernel
        wireBridges()
    }

    /// 把当前 editorService / kernel 注入到各姊妹插件的 bridge。
    public static func wireBridges() {
        let service = editorService

        // Preview:无参 editorServiceProvider + 单参 addToChatHandler
        EditorPreviewRuntimeBridge.editorServiceProvider = { service }
        EditorPreviewRuntimeBridge.addToChatHandler = { text in
            NotificationCenter.default.post(
                name: Notification.Name("addToChat"),
                object: nil,
                userInfo: [
                    "text": text,
                    "windowId": service?.state.windowId as Any,
                ]
            )
        }

        // StickySymbolBar:无参 editorServiceProvider
        EditorStickySymbolBarBridge.editorServiceProvider = { service }

        // BottomTerminal:无参 editorThemeIdProvider;project path 由 bridge 自行从 kernel 读取
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            let scheme = SystemAppearanceResolver.effectiveColorScheme
            return LumiUIThemeRegistry.shared.resolvedEditorThemeId(colorScheme: scheme) ?? "xcode-dark"
        }
    }
}
