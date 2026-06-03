import Foundation
import EditorService
import LumiCoreKit
/// LSP Inlay Hint 编辑器插件。
///
/// 该插件负责把 `InlayHintProvider` 注册到编辑器扩展注册中心，
/// 为编辑器提供基于 LSP `textDocument/inlayHint` 的内联提示能力，
/// 例如参数名提示、类型推断提示等。
///
/// 本插件目录中的 `Views/InlayHintLabel.swift` 提供单个 hint 的显示组件；
/// 主入口只注册 Provider，不负责计算视图位置或直接挂载 UI。实际展示位置由编辑器 Overlay
/// 或消费 `SuperEditorInlayHintProvider` 的 UI 决定。
public actor LSPInlayHintEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = LSPInlayHintEditorPlugin()
    public static let id = "LSPInlayHintEditor"
    public static let displayName = String(localized: "LSP Inlay Hints", bundle: .module)
    public static let description = String(localized: "Displays type inference and parameter name hints inline.", bundle: .module)
    public static let iconName = "textformat.size"
    public static let order = 22
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let provider = InlayHintProvider(lspService: .shared)
        registry.registerInlayHintProvider(provider)
    }
}
