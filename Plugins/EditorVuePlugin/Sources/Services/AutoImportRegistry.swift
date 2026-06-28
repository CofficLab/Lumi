import Foundation
import os
import SuperLogKit

/// 自动导入注册表
///
/// 管理由 `unplugin-vue-components`、`unplugin-auto-import` 等
/// 自动导入插件生成的组件和 API 注册信息。
///
/// 这些插件会在项目中生成 `components.d.ts` 和 `auto-imports.d.ts` 文件，
/// 本模块解析这些文件，为编辑器提供准确的组件和 API 补全。
struct AutoImportRegistry: Sendable, SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.auto-import"
    )

    // MARK: - 注册条目

    /// 自动导入的组件条目
    struct ComponentEntry: Sendable {
        /// 组件名（PascalCase）
        let name: String

        /// 导入来源（如 "ant-design-vue/es/button"）
        let importFrom: String

        /// 导入的默认名称
        let importName: String

        /// 所在文件路径
        let resolvedPath: String?
    }

    /// 自动导入的 API 条目
    struct APIEntry: Sendable {
        /// API 名称（如 "ref", "computed", "useRouter"）
        let name: String

        /// 导入来源（如 "vue", "vue-router"）
        let importFrom: String

        /// 是否为默认导入
        let isDefault: Bool

        /// 是否为类型导入
        let isType: Bool
    }

    // MARK: - 解析结果

    /// 项目自动导入注册信息
    struct Registry: Sendable {
        /// 自动注册的组件
        let components: [String: ComponentEntry]

        /// 自动注册的 API
        let apis: [String: APIEntry]

        /// 扫描时间戳
        let timestamp: Date
    }

    // MARK: - 文件名

    /// 自动生成的声明文件名
    private static let componentsFileName = "components.d.ts"
    private static let autoImportsFileName = "auto-imports.d.ts"

    // MARK: - 扫描项目

    /// 扫描项目的自动导入注册
    ///
    /// - Parameter projectPath: 项目根目录
    /// - Returns: 注册信息
    static func scan(projectPath: String) -> Registry {
        var components: [String: ComponentEntry] = [:]
        var apis: [String: APIEntry] = [:]

        // 1. 解析 components.d.ts
        let componentsPath = (projectPath as NSString).appendingPathComponent(componentsFileName)
        if let content = try? VueTextFileIO.readContent(path: componentsPath) {
            components = parseComponentsDTS(content)
            if EditorVuePlugin.verbose {
                logger.info("\(Self.t)\(emoji) 解析 components.d.ts: \(components.count) 个组件")
            }
        }

        // 2. 解析 auto-imports.d.ts
        let autoImportsPath = (projectPath as NSString).appendingPathComponent(autoImportsFileName)
        if let content = try? VueTextFileIO.readContent(path: autoImportsPath) {
            apis = parseAutoImportsDTS(content)
            if EditorVuePlugin.verbose {
                logger.info("\(Self.t)\(emoji) 解析 auto-imports.d.ts: \(apis.count) 个 API")
            }
        }

        // 3. 尝试 src/ 子目录（某些项目结构）
        if components.isEmpty && apis.isEmpty {
            let srcComponentsPath = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("src")
                .appendingPathComponent(componentsFileName)
                .path
            if let content = try? VueTextFileIO.readContent(path: srcComponentsPath) {
                components = parseComponentsDTS(content)
            }

            let srcAutoImportsPath = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("src")
                .appendingPathComponent(autoImportsFileName)
                .path
            if let content = try? VueTextFileIO.readContent(path: srcAutoImportsPath) {
                apis = parseAutoImportsDTS(content)
            }
        }

        return Registry(
            components: components,
            apis: apis,
            timestamp: Date()
        )
    }

    // MARK: - 解析 components.d.ts

    /// 解析 unplugin-vue-components 生成的声明文件
    ///
    /// 文件格式示例：
    /// ```ts
    /// declare module '@vue/runtime-core' {
    ///   export interface GlobalComponents {
    ///     RouterLink: typeof import('vue-router')['RouterLink']
    ///     ElButton: typeof import('element-plus/es')['ElButton']
    ///   }
    /// }
    /// ```
    private static func parseComponentsDTS(_ content: String) -> [String: ComponentEntry] {
        var components: [String: ComponentEntry] = [:]

        // 匹配 ComponentName: typeof import('source')['ExportName']
        let pattern = #"(\w+)\s*:\s*typeof\s+import\s*\(\s*['"]([^'"]+)['"]\s*\)\s*\[\s*['"]([^'"]*)['"]\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [:] }

        let nsRange = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: nsRange) {
            guard let nameRange = Range(match.range(at: 1), in: content),
                  let fromRange = Range(match.range(at: 2), in: content),
                  let exportRange = Range(match.range(at: 3), in: content) else {
                continue
            }

            let name = String(content[nameRange])
            let importFrom = String(content[fromRange])
            let exportName = String(content[exportRange])

            components[name] = ComponentEntry(
                name: name,
                importFrom: importFrom,
                importName: exportName.isEmpty ? name : exportName,
                resolvedPath: nil
            )
        }

        return components
    }

    // MARK: - 解析 auto-imports.d.ts

    /// 解析 unplugin-auto-import 生成的声明文件
    ///
    /// 文件格式示例：
    /// ```ts
    /// declare global {
    ///   const ref: typeof import('vue')['ref']
    ///   const computed: typeof import('vue')['computed']
    ///   const useRouter: typeof import('vue-router')['useRouter']
    /// }
    /// ```
    private static func parseAutoImportsDTS(_ content: String) -> [String: APIEntry] {
        var apis: [String: APIEntry] = [:]

        // 匹配 const/apiName: typeof import('source')['exportName']
        // 也匹配 type ApiName = ...
        let pattern = #"(?:const|let|var|type)\s+(\w+)\s*(?::\s*typeof\s+import\s*\(\s*['"]([^'"]+)['"]\s*\)\s*\[\s*['"]([^'"]*)['"]\s*\])?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [:] }

        let nsRange = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: nsRange) {
            guard let nameRange = Range(match.range(at: 1), in: content) else { continue }
            let name = String(content[nameRange])

            // 检查是否有完整的 import 信息
            if let fromRange = Range(match.range(at: 2), in: content),
               let exportRange = Range(match.range(at: 3), in: content) {
                let importFrom = String(content[fromRange])

                apis[name] = APIEntry(
                    name: name,
                    importFrom: importFrom,
                    isDefault: false,
                    isType: false
                )
            }
        }

        return apis
    }

    // MARK: - 缓存

    nonisolated(unsafe) private static var cache: [String: Registry] = [:]
    private static let cacheLock = NSLock()

    /// 获取缓存的注册信息
    static func cachedRegistry(projectPath: String) -> Registry? {
        cacheLock.lock()
        if let cached = cache[projectPath] {
            let age = Date().timeIntervalSince(cached.timestamp)
            cacheLock.unlock()
            // 30 秒内缓存有效
            return age < 30 ? cached : nil
        }
        cacheLock.unlock()
        return nil
    }

    /// 获取或扫描注册信息
    static func registry(for projectPath: String) -> Registry {
        if let cached = cachedRegistry(projectPath: projectPath) {
            return cached
        }
        let result = scan(projectPath: projectPath)
        cacheLock.lock()
        cache[projectPath] = result
        cacheLock.unlock()
        return result
    }

    /// 清除缓存
    static func invalidateCache(projectPath: String) {
        cacheLock.lock()
        cache.removeValue(forKey: projectPath)
        cacheLock.unlock()
    }
}
