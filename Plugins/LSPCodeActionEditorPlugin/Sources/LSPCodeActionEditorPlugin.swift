import Foundation
import EditorService
import LumiCoreKit
import SwiftUI
/// LSP Code Action 编辑器插件。
///
/// 该插件负责把 `CodeActionProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 Language Server Protocol 的代码动作能力。
/// 当当前行或当前诊断存在可修复问题时，Provider 会通过 LSP 的
/// `textDocument/codeAction` 请求获取快速修复、重构、组织导入等候选动作。
///
/// `CodeActionProvider` 还会合并其它编辑器插件提供的本地 `EditorCodeActionSuggestion`，
/// 并在执行动作时负责解析 LSP lazy code action、应用 `WorkspaceEdit`，或调用
/// `workspace/executeCommand`。
///
/// 本插件目录中的 `Views` 目录包含用于展示 Code Action 结果的 SwiftUI 组件，例如：
/// - `CodeActionPanel`：展示可选动作列表的弹窗内容。
/// - `CodeActionRow`：展示单个动作。
/// - `LightbulbIndicator`：提示当前位置存在可用动作的灯泡图标。
///
/// 插件主入口只注册 Provider；具体何时请求动作、在哪里显示灯泡或弹窗，
/// 由编辑器状态、Overlay 或消费 `SuperEditorCodeActionProvider` 的 UI 负责。
public enum LSPCodeActionEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "lightbulb"

    public static let info = LumiPluginInfo(
        id: "LSPCodeActionEditor",
        displayName: LumiPluginLocalization.string("LSP Code Actions", bundle: .module),
        description: LumiPluginLocalization.string("Provides quick-fix code actions and lightbulb suggestions for diagnostics.", bundle: .module),
        order: 20
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = CodeActionProvider(lspService: .shared)
        provider.editorExtensionRegistry = registry
        registry.registerCodeActionProvider(provider)
    }
}
