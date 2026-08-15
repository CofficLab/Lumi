import SwiftUI

/// 主内容视图提供能力协议
///
/// 定义「内核 → 主内容区」这一段的最小契约：插件（如 DevicePlugin）在
/// `onBoot` 中解析 `ContentViewProviding`，通过 `setContentView(_:)`
/// 注册自己的主要内容；RootView 的内容区据此渲染。
///
/// 协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ContentViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol ContentViewProviding: AnyObject {
    /// 设置当前主内容视图（传 `nil` 表示清空，回退到占位）。
    func setContentView(_ view: AnyView?)

    /// 返回当前主内容视图；未设置时返回占位视图。
    func makeContentView() -> AnyView
}
