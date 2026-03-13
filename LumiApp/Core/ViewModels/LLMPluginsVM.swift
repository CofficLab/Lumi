import Foundation
import MagicKit
import OSLog
import ObjectiveC.runtime

/// LLM 插件加载器
///
/// 使用 Objective‑C Runtime 扫描所有以 `LLMPlugin` 结尾的类，
/// 找出实现了 `SuperLLMProviderPlugin` 协议的类型，并调用其
/// `registerProviders(to:)` 方法把具体的 LLM 供应商类型注册到 `ProviderRegistry`。
enum LLMPluginsVM: SuperLog {

    nonisolated static let emoji = "🧩"
    nonisolated static let verbose = true

    /// 扫描并注册所有 LLM 提供者插件
    ///
    /// - Parameter registry: 要注册到的供应商注册表实例
    static func registerAllProviders(to registry: ProviderRegistry) {
        var count: UInt32 = 0
        guard let classList = objc_copyClassList(&count) else {
            return
        }
        defer {
            free(UnsafeMutableRawPointer(classList))
        }

        let classes = UnsafeBufferPointer(start: classList, count: Int(count))
        var discoveredTypes: [(type: SuperLLMProviderPlugin.Type, name: String, order: Int)] = []

        for i in 0 ..< classes.count {
            let cls: AnyClass = classes[i]
            let className = NSStringFromClass(cls)

            // 仅匹配 Lumi 命名空间且以 LLMPlugin 结尾的类
            guard className.hasPrefix("Lumi."),
                  className.hasSuffix("LLMPlugin") else {
                continue
            }

            // 尝试转换为 SuperLLMProviderPlugin 类型
            guard let pluginType = cls as? SuperLLMProviderPlugin.Type else {
                continue
            }

            // 跳过静态关闭的插件
            guard pluginType.enable else {
                continue
            }

            discoveredTypes.append((type: pluginType, name: className, order: pluginType.order))
        }

        // 按顺序排序，确保核心/基础插件优先注册
        discoveredTypes.sort { $0.order < $1.order }

        for item in discoveredTypes {
            item.type.registerProviders(to: registry)
            if Self.verbose {
                os_log("\(self.t)✅ Registered LLM providers from plugin: \(item.name) (order: \(item.order))")
            }
        }

        if Self.verbose {
            os_log("\(self.t)🔍 LLM plugins loaded: \(discoveredTypes.count)")
        }
    }
}

