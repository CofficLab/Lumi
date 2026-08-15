import SwiftUI

/// 窗口/根视图提供能力协议
///
/// 定义「内核 → 主窗口内容」这一段的最小契约：宿主（App）在启动时
/// 通过内核解析 `WindowProviding`，拿到根内容视图后包进 `WindowGroup` 展示。
///
/// SwiftUI 中没有可注册的 "Window" 对象——窗口由 `WindowGroup` scene 定义，
/// 因此本协议返回**根内容视图**（`AnyView`），窗口的呈现（标题、尺寸、
/// 样式等）由宿主 App 在 `Scene` 中决定。这与现有 FactoryLumi
/// `makeMainWindow() -> some View` 的先例语义一致。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any WindowProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol WindowProviding: AnyObject {
    /// 返回主窗口的根内容视图。
    func makeRootView() -> AnyView
}
