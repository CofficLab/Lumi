import Foundation
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
/// LSP 选区范围编辑器插件。
///
/// 该插件对应 LSP `textDocument/selectionRange` 能力，用于支持智能扩大/缩小选区。
/// 语言服务器会根据当前光标位置返回语义化的嵌套选区范围，例如表达式、语句、函数体等。
///
/// 当前主入口暂未直接注册 Provider，保留为独立插件边界，方便后续把 selection range 能力接入
/// 编辑器命令或多光标/选择系统。本插件本身不提供 View。
public actor LSPSelectionRangeEditorPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = LSPSelectionRangeEditorPlugin()
    public static let id = "LSPSelectionRangeEditor"
    public static let displayName = LumiPluginLocalization.string("LSP Selection Ranges", bundle: .module)
    public static let description = LumiPluginLocalization.string("Provides smart expand/shrink selection via LSP selection ranges.", bundle: .module)
    public static let iconName = "rectangle.on.rectangle"
    public static let order = 27
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        // Provided via SelectionRangeProvider
    }
}
