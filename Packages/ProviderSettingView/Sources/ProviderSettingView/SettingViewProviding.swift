import SwiftUI

/// 设置视图提供能力协议
///
/// 定义「内核 → 设置窗口内容」这一段的最小契约：宿主在启动时
/// 通过内核解析 `SettingViewProviding`，拿到设置视图后作为设置窗口内容展示。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerEntries(_:)` 注入 `SettingEntryItem`（侧边栏入口）；
/// - 实现负责把注入的入口渲染成「左侧入口列表 + 右侧详情视图」的设置界面
///   （`makeSettingView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any SettingViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol SettingViewProviding: AnyObject {
    /// 当前已注入的全部设置入口项。
    var entries: [SettingEntryItem] { get }

    /// 注入设置入口项（替换当前全部项）。
    func registerEntries(_ entries: [SettingEntryItem])

    /// 返回设置视图（基于已注入的入口渲染）。
    func makeSettingView() -> AnyView
}
