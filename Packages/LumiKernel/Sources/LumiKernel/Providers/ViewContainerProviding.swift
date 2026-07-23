import Foundation
import SwiftUI

// MARK: - View Container Capability Protocol

/// 视图容器能力协议
///
/// 定义 LumiCore 需要的视图容器管理功能，由具体布局插件实现。
/// 负责管理所有插件的 ViewContainer 注册、排序、查询和激活状态。
@MainActor
public protocol ViewContainerProviding: ObservableObject {
    /// 所有视图容器（按 order 排序）
    var allViewContainers: [ViewContainerItem] { get }

    /// 按 ID 查询视图容器
    func viewContainer(id: String) -> ViewContainerItem?

    /// 当前激活的视图容器 ID
    var activeContainerID: String? { get set }

    /// 激活指定视图容器
    func activate(id: String)

    /// 注册视图容器
    func register(_ container: ViewContainerItem)

    /// 注销视图容器
    func unregister(id: String)

    /// 清空所有插件贡献(供全量重建使用)。默认 no-op。
    func clearAllContributions()
}

public extension ViewContainerProviding {
    func clearAllContributions() {}
}
