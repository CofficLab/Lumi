import Foundation
import KernelCore
import SwiftUI

/// 产出视图的工厂协议。
///
/// 集中管理视图组装逻辑：主窗口视图、设置窗口视图以及 LumiUI 主题桥接。
/// `KernelFactory` 负责创建内核并装配 Provider / Plugin，视图组装全部
/// 委托给 `ViewFactory` 完成；宿主可实现该协议覆盖视图组装逻辑
/// （如注入额外的工具条、替换设置侧边栏头部等）。
@MainActor
public protocol ViewFactory {
    /// 使用已装配的内核组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// 视图组装逻辑集中在此：宿主只需要一个视图，无需关心内核如何把
    /// 各 Provider 的能力组合起来。返回的视图应用了当前选中主题
    /// （明暗外观 + 背景色）。
    ///
    /// - Parameter kernel: 已装配的 `KernelCoreContainer`（由 `KernelFactory`
    ///   `makeKernel` 产出；主窗口 / 设置窗口 / 菜单栏共享同一实例）。
    /// - Returns: 已装配的根视图（`AnyView`）。
    func makeMainView(kernel: KernelCoreContainer) throws -> AnyView

    /// 使用已装配的内核返回设置视图。
    ///
    /// 设置视图的入口由已启动的插件（如 SettingGeneralPlugin）贡献；
    /// 宿主只需把返回的视图放进设置窗口（如 `Window("设置")`）即可。
    ///
    /// - Parameter kernel: 已装配的 `KernelCoreContainer`（共享内核时使用）。
    /// - Returns: 已装配的设置视图（`AnyView`）。
    func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView
}
