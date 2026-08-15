import SwiftUI

/// 文档视图提供能力协议
///
/// 定义「内核 → 插件文档（关于 / 说明书）」这一段的最小契约：插件在
/// `onBoot` 中解析 `DocsViewProviding`，通过 `setAboutView(_:)` /
/// `setManualView(_:)` 注入自己的关于页与说明书；宿主在合适位置
/// （如插件管理、设置）展示。
///
/// 协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any DocsViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol DocsViewProviding: AnyObject {
    /// 设置「关于」视图（传 `nil` 表示无关于页）。
    func setAboutView(_ view: AnyView?)

    /// 设置「说明书」视图（传 `nil` 表示无说明书）。
    func setManualView(_ view: AnyView?)

    /// 返回「关于」视图；未设置时返回占位。
    func makeAboutView() -> AnyView

    /// 返回「说明书」视图；未设置时返回占位。
    func makeManualView() -> AnyView
}
