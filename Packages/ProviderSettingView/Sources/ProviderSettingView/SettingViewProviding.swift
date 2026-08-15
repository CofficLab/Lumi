import SwiftUI

/// 设置视图提供能力协议
///
/// 定义「内核 → 设置窗口内容」这一段的最小契约：宿主在启动时
/// 通过内核解析 `SettingViewProviding`，拿到设置视图后作为设置窗口内容展示。
///
/// 协议只声明能力，不关心具体实现——设置项、分组、布局均由注入的实现决定。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any SettingViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol SettingViewProviding: AnyObject {
    /// 返回设置视图。
    func makeSettingView() -> AnyView
}
