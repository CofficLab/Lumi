import Foundation
import ObjectiveC.runtime
import SwiftUI

/// 插件注册协议，所有插件类需要实现此协议以支持自动注册
@objc protocol PluginRegistrant {
    static func register()
}

/// 插件注册表，负责插件的注册和管理
actor PluginRegistry {
    /// 单例实例
    static let shared = PluginRegistry()

    /// 插件工厂项列表，包含插件ID、顺序和工厂方法
    private var factoryItems: [(id: String, order: Int, factory: () -> any SuperPlugin)] = []

    /// 私有初始化方法，确保单例模式
    private init() {}

    /// 注册插件
    /// - Parameters:
    ///   - id: 插件唯一标识符
    ///   - order: 插件加载顺序（数字越小越先加载）
    ///   - factory: 插件工厂方法
    func register(id: String, order: Int = 0, factory: @escaping () -> any SuperPlugin) {
        // 检查是否已经注册过，避免重复注册
        if factoryItems.contains(where: { $0.id == id }) {
            print("⚠️ PluginRegistry: 插件 '\(id)' 已注册，忽略重复注册")
            return
        }
        
        factoryItems.append((id: id, order: order, factory: factory))
        print("✅ PluginRegistry: 已注册插件 '\(id)' (order: \(order))")
    }

    /// 构建所有已注册的插件实例
    /// - Returns: 按顺序排列的插件实例数组
    func buildAll() -> [any SuperPlugin] {
        factoryItems
            .sorted { $0.order < $1.order }
            .map { $0.factory() }
    }

    /// 获取已注册的插件数量
    /// - Returns: 插件数量
    func count() -> Int {
        factoryItems.count
    }

    /// 检查插件是否已注册
    /// - Parameter id: 插件ID
    /// - Returns: 是否已注册
    func isRegistered(_ id: String) -> Bool {
        factoryItems.contains { $0.id == id }
    }
}

/// 自动注册所有符合PluginRegistrant协议的插件类
/// 使用Objective-C运行时扫描所有已加载的类，找到实现PluginRegistrant协议的类并调用其register()方法
@MainActor
func autoRegisterPlugins() {
    var count: UInt32 = 0
    guard let classList = objc_copyClassList(&count) else { return }
    defer { free(UnsafeMutableRawPointer(classList)) }

    let classes = UnsafeBufferPointer(start: classList, count: Int(count))
    for i in 0 ..< classes.count {
        let cls: AnyClass = classes[i]
        if class_conformsToProtocol(cls, PluginRegistrant.self) {
            (cls as? PluginRegistrant.Type)?.register()
        }
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
