import EditorService
import LumiCoreKit

/// Editor Chat 插件：在编辑器右键菜单提供「Add to Chat」，
/// 把选中代码的文件路径与行范围（或光标所在行）追加到对话输入框。
public enum EditorChatPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-chat",
        displayName: LumiPluginLocalization.string("Editor Chat", bundle: .module),
        description: LumiPluginLocalization.string(
            "Adds an \"Add to Chat\" command to the editor context menu to append the selected code's file reference to the chat composer.",
            bundle: .module
        ),
        order: 6,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "plus.bubble"
    )

    /// 注册编辑器扩展（右键菜单命令贡献器）。
    @MainActor
    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerCommandContributor(EditorChatSelectionCommandContributor())
    }
}
