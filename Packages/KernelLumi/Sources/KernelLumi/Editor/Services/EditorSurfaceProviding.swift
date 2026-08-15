import LumiUI
import SwiftUI

/// 编辑器 Surface 能力（契约 V2，见重构方案 §8.1 / §13）。
///
/// 标准 Surface（TextView + Overlay 装配）由 Host 统一组装，
/// Shell UI 插件（如 EditorPanelPlugin）通过本能力取得编辑器视图，
/// 不依赖具体编辑器实现（`EditorService` / `EditorSource`）。
///
/// 本协议属于 KernelLumi 的 UI 契约分区，允许使用 `AnyView`；
/// Feature Provider 协议禁止混入 SwiftUI 类型（§13.2）。
@MainActor
public protocol EditorSurfaceProviding: AnyObject {
    /// 创建编辑器 Surface 视图。
    ///
    /// Host 未完成装配时返回占位视图，绝不返回 nil。
    func makeEditorView() -> AnyView
}
