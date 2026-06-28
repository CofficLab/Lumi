import Foundation
import os
import SuperLogKit

/// tsconfig.json 中 Vue 相关配置与路径别名解析
///
/// 职责：
/// 1. 解析 `tsconfig.json`（及 `jsconfig.json`）中的 `compilerOptions.paths`，将 `@/*` 这类别名映射为实际文件路径
/// 2. 读取 `vueCompilerOptions` 中的 Volar 专用配置
/// 3. 为组件导入解析、跳转定义、自动导入等功能提供路径解析服务
struct TSConfigVueExtender: Sendable, SuperLog {
    nonisolated static let emoji = "📐"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.tsconfig"
    )

    // MARK: - 解析结果

    /// tsconfig 解析结果
    struct TSConfigInfo {
        /// 配置文件路径
        let configPath: String

        /// 基础目录（compilerOptions.baseUrl）
        let baseUrl: String?

        /// 路径别名映射：别名模式 → 目标路径列表
        /// 例: ["@/*": ["src/*"], "~/*": ["src/*"]]
        let paths: [String: [String]]

        /// Vue 编译器选项（vueCompilerOptions）
        let vueCompilerOptions: [String: Any]

        /// 目标模块（compilerOptions.target）
        let target: String?

        /// 模块解析策略（compilerOptions.moduleResolution）
        let moduleResolution: String?

        /// 严格模式
        let strict: Bool

        /// 是否启用了 JSX
        let jsx: String?
    }

    // MARK: - 查找配置文件

    /// tsconfig 可能的文件名（按优先级）
    private static let configFileNames: [String] = [
        "tsconfig.json",
        "tsconfig.app.json",
        "tsconfig.node.json",
        "jsconfig.json",
    ]

    /// 在项目中查找 tsconfig 配置
    ///
    /// - Parameter projectPath: 项目根目录
    /// - Returns: 找到的第一个配置文件路径
    static func findConfig(in projectPath: String) -> String? {
        let fm = FileManager.default
        for name in configFileNames {
            let path = (projectPath as NSString).appendingPathComponent(name)
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - 解析配置

    /// 解析项目的 tsconfig.json
    ///
    /// - Parameter projectPath: 项目根目录
    /// - Returns: 解析结果
    static func parse(projectPath: String) -> TSConfigInfo? {
        guard let configPath = findConfig(in: projectPath) else { return nil }
        return parse(at: configPath, projectPath: projectPath)
    }

    /// 解析指定路径的 tsconfig
    static func parse(at configPath: String, projectPath: String) -> TSConfigInfo? {
        guard let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let compilerOptions = json["compilerOptions"] as? [String: Any] ?? [:]
        let vueCompilerOptions = json["vueCompilerOptions"] as? [String: Any] ?? [:]

        let baseUrl = compilerOptions["baseUrl"] as? String
        let paths = compilerOptions["paths"] as? [String: [String]] ?? [:]
        let target = compilerOptions["target"] as? String
        let moduleResolution = compilerOptions["moduleResolution"] as? String
        let strict = compilerOptions["strict"] as? Bool ?? false
        let jsx = compilerOptions["jsx"] as? String

        if EditorVuePlugin.verbose {
            logger.info("\(Self.t)\(emoji) 解析 tsconfig: \(configPath), baseUrl=\(baseUrl ?? "nil"), paths=\(paths.count), vueOptions=\(vueCompilerOptions.count)")
        }

        return TSConfigInfo(
            configPath: configPath,
            baseUrl: baseUrl,
            paths: paths,
            vueCompilerOptions: vueCompilerOptions,
            target: target,
            moduleResolution: moduleResolution,
            strict: strict,
            jsx: jsx
        )
    }

    // MARK: - 路径别名解析

    /// 将别名路径解析为实际文件路径
    ///
    /// - Parameters:
    ///   - aliasPath: 别名路径（如 `@/components/MyButton.vue`）
    ///   - projectPath: 项目根目录
    ///   - config: 已解析的 tsconfig 信息（可选，不传则自动解析）
    /// - Returns: 解析后的实际路径，无法解析时返回原始路径
    static func resolveAlias(
        _ aliasPath: String,
        projectPath: String,
        config: TSConfigInfo? = nil
    ) -> String {
        let info = config ?? parse(projectPath: projectPath)

        guard let info else { return aliasPath }

        // 遍历路径别名规则
        for (pattern, targets) in info.paths {
            // 处理通配符模式: "@/*" -> 匹配 "@/xxx"
            if pattern.hasSuffix("/*") {
                let prefix = String(pattern.dropLast(2)) // 去掉 "/*"
                if aliasPath.hasPrefix(prefix + "/") {
                    let suffix = String(aliasPath.dropFirst(prefix.count + 1))
                    for target in targets {
                        let targetPrefix = String(target.dropLast(2)) // "src/*" -> "src"
                        let resolved = URL(fileURLWithPath: projectPath)
                            .appendingPathComponent(targetPrefix)
                            .appendingPathComponent(suffix)
                            .path
                        return resolved
                    }
                }
            }

            // 精确匹配
            if aliasPath == pattern {
                if let first = targets.first {
                    return (projectPath as NSString).appendingPathComponent(first)
                }
            }
        }

        return aliasPath
    }

    /// 检查给定的导入路径是否使用了路径别名
    static func isAliasedPath(_ importPath: String, projectPath: String) -> Bool {
        guard let info = parse(projectPath: projectPath) else { return false }
        for pattern in info.paths.keys {
            if pattern.hasSuffix("/*") {
                let prefix = String(pattern.dropLast(2))
                if importPath.hasPrefix(prefix + "/") { return true }
            } else if importPath == pattern {
                return true
            }
        }
        return false
    }

    // MARK: - Vue 编译器选项

    /// Vue 目标版本（从 vueCompilerOptions.target 读取）
    static func vueTarget(config: TSConfigInfo?) -> VueVersionDetector.VueVersion {
        guard let config else { return .unknown }
        if let target = config.vueCompilerOptions["target"] as? String {
            if target.hasPrefix("2") { return .vue2 }
            if target.hasPrefix("3") || target == "next" { return .vue3 }
        }
        return .unknown
    }

    /// 是否启用严格模板检查
    static func strictTemplates(config: TSConfigInfo?) -> Bool {
        config?.vueCompilerOptions["strictTemplates"] as? Bool ?? false
    }

    /// 自定义元素列表（isCustomElement 配置）
    static func customElements(config: TSConfigInfo?) -> Set<String> {
        guard let names = config?.vueCompilerOptions["isCustomElement"] as? [String] else { return [] }
        return Set(names)
    }

    // MARK: - 缓存

    nonisolated(unsafe) private static var cache: [String: TSConfigInfo] = [:]
    private static let cacheLock = NSLock()

    /// 获取缓存的配置（带自动解析）
    static func cachedConfig(projectPath: String) -> TSConfigInfo? {
        cacheLock.lock()
        if let cached = cache[projectPath] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let info = parse(projectPath: projectPath) else { return nil }

        cacheLock.lock()
        cache[projectPath] = info
        cacheLock.unlock()

        return info
    }

    /// 清除缓存
    static func invalidateCache(projectPath: String) {
        cacheLock.lock()
        cache.removeValue(forKey: projectPath)
        cacheLock.unlock()
    }
}
