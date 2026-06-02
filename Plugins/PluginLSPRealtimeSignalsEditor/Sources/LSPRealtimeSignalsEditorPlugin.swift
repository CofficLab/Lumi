import Foundation
import EditorService
import LumiCoreKit
/// LSP 实时信号编辑器插件。
///
/// 该插件向编辑器注册 `LSPRealtimeInteractionContributor`，用于把编辑器中的实时交互事件
/// 转换为 LSP 相关刷新信号，例如光标移动、文本变更、可见区域变化后触发高亮、签名帮助、
/// inlay hint 或 code action 刷新。
///
/// 本插件不直接请求具体 LSP 数据，也不提供 View；它更像事件桥接层，负责把编辑器运行时事件
/// 分发给其它 LSP Provider 或编辑器状态处理逻辑。
public actor LSPRealtimeSignalsEditorPlugin: SuperPlugin {
    public static let shared = LSPRealtimeSignalsEditorPlugin()
    public static let id = "LSPRealtimeSignalsEditor"
    public static let displayName = String(localized: "LSP Realtime Signals", table: "LSPRealtimeSignalsEditor")
    public static let description = String(localized: "Triggers realtime LSP updates for highlights, hints, and signature help.", table: "LSPRealtimeSignalsEditor")
    public static let iconName = "wifi"
    public static let order = 18
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerInteractionContributor(LSPRealtimeInteractionContributor())
    }
}
