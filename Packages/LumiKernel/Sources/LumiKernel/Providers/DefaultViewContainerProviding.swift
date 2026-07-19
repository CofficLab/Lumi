import Foundation
import SwiftUI

// MARK: - Default View Container Provider

/// 默认视图容器提供者
///
/// 负责管理所有插件的 ViewContainer 注册、排序、查询和激活状态。
/// 作为 ViewContainerProviding 协议的默认实现，由 LumiKernel 持有。
@MainActor
public final class DefaultViewContainerProviding: ViewContainerProviding {
    public private(set) var allViewContainers: [ViewContainerItem] = []
    public var activeContainerID: String?

    private var viewContainers: [String: ViewContainerItem] = [:]
    private var viewContainerOrder: [String] = []

    public init() {}

    public func viewContainer(id: String) -> ViewContainerItem? {
        viewContainers[id]
    }

    public func activate(id: String) {
        activeContainerID = id
    }

    public func register(_ container: ViewContainerItem) {
        if viewContainers[container.id] == nil {
            viewContainerOrder.append(container.id)
        }
        viewContainers[container.id] = container
        updateSortedContainers()
    }

    public func unregister(id: String) {
        viewContainers.removeValue(forKey: id)
        viewContainerOrder.removeAll { $0 == id }
        updateSortedContainers()
    }

    private func updateSortedContainers() {
        allViewContainers = viewContainerOrder.compactMap { viewContainers[$0] }
            .sorted { $0.order < $1.order }
    }
}
