import Foundation
import os
import SuperLogKit

/// Vue 编译器选项读取
///
/// 从以下来源读取 Vue 编译器选项（按优先级）：
/// 1. `tsconfig.json` 中的 `vueCompilerOptions`
/// 2. `vite.config.ts` / `vite.config.js` 中的 `vue()` 插件配置
/// 3. `vue.config.js`（Vue CLI 项目，仅 Vue 2）
///
/// 这些选项影响 Volar 的行为和模板编译策略。
struct VueCompilerOptions: Sendable, SuperLog {
    nonisolated static let emoji = "⚙️"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.compiler-options"
    )

    // MARK: - 选项模型

    /// Vue 编译器选项集合
    struct Options {
        /// 目标版本
        let target: VueVersionDetector.VueVersion

        /// 严格模板模式
        let strictTemplates: Bool

        /// 是否将原生 HTML 标签视为自定义元素
        let isCustomElement: Set<String>

        /// 解构的 prop 名称（Vue 3.3+ 的 reactivePropsDestructure）
        let destructuredPropNames: Set<String>

        /// 是否启用 JSX 支持
        let jsxEnabled: Bool

        /// 数据属性名（v-bind 的简写名）
        let dataAttributePrefix: String?

        /// 模板编译选项
        let templateCompilerOptions: [String: Any]

        /// 来源描述（用于调试）
        let sourceDescription: String
    }

    /// 默认选项
    nonisolated(unsafe) static let defaults = Options(
        target: .unknown,
        strictTemplates: false,
        isCustomElement: [],
        destructuredPropNames: [],
        jsxEnabled: false,
        dataAttributePrefix: nil,
        templateCompilerOptions: [:],
        sourceDescription: "defaults"
    )

    // MARK: - 解析

    /// 从项目中读取编译器选项
    ///
    /// - Parameter projectPath: 项目根目录
    /// - Returns: 合并后的编译器选项
    static func read(from projectPath: String) -> Options {
        var options = defaults
        var sources: [String] = []

        // 1. 从 tsconfig.json / vueCompilerOptions 读取
        if let tsconfig = TSConfigVueExtender.parse(projectPath: projectPath) {
            let vueOpts = tsconfig.vueCompilerOptions

            let target = vueOpts["target"] as? String
            if let t = target {
                if t.hasPrefix("2") { options = options.with(target: .vue2) }
                else if t.hasPrefix("3") || t == "next" { options = options.with(target: .vue3) }
            }

            if let strict = vueOpts["strictTemplates"] as? Bool {
                options = options.with(strictTemplates: strict)
            }

            if let names = vueOpts["isCustomElement"] as? [String] {
                options = options.with(isCustomElement: Set(names))
            }

            if let names = vueOpts["plugins"] as? [String] {
                // 检查是否启用了 JSX
                if names.contains(where: { $0.contains("jsx") }) {
                    options = options.with(jsxEnabled: true)
                }
            }

            // 从 tsconfig compilerOptions 读取 jsx
            if let jsx = tsconfig.jsx, !jsx.isEmpty, jsx != "preserve" {
                options = options.with(jsxEnabled: true)
            }

            sources.append("tsconfig")
        }

        // 2. 从 vite.config 检测 JSX
        if let viteConfig = ViteBridge.detect(projectPath: projectPath) {
            let viteConfigPath = viteConfig.configPath
            if let content = try? VueTextFileIO.readContent(path: viteConfigPath) {
                if content.contains("vueJsx") || content.contains("@vitejs/plugin-vue-jsx") {
                    options = options.with(jsxEnabled: true)
                    sources.append("vite.config")
                }
            }
        }

        options = options.with(sourceDescription: sources.isEmpty ? "defaults" : sources.joined(separator: " + "))

        if EditorVuePlugin.verbose {
            logger.info("\(Self.t)\(emoji) Vue 编译器选项: target=\(options.target.rawValue), strict=\(options.strictTemplates), jsx=\(options.jsxEnabled), customElements=\(options.isCustomElement.count), source=\(options.sourceDescription)")
        }

        return options
    }

    // MARK: - Options 修改辅助

    // 使用扩展方法避免每个属性都写一个 with 方法
}

extension VueCompilerOptions.Options {
    func with(target: VueVersionDetector.VueVersion) -> Self {
        VueCompilerOptions.Options(
            target: target,
            strictTemplates: strictTemplates,
            isCustomElement: isCustomElement,
            destructuredPropNames: destructuredPropNames,
            jsxEnabled: jsxEnabled,
            dataAttributePrefix: dataAttributePrefix,
            templateCompilerOptions: templateCompilerOptions,
            sourceDescription: sourceDescription
        )
    }

    func with(strictTemplates: Bool) -> Self {
        VueCompilerOptions.Options(
            target: target,
            strictTemplates: strictTemplates,
            isCustomElement: isCustomElement,
            destructuredPropNames: destructuredPropNames,
            jsxEnabled: jsxEnabled,
            dataAttributePrefix: dataAttributePrefix,
            templateCompilerOptions: templateCompilerOptions,
            sourceDescription: sourceDescription
        )
    }

    func with(isCustomElement: Set<String>) -> Self {
        VueCompilerOptions.Options(
            target: target,
            strictTemplates: strictTemplates,
            isCustomElement: isCustomElement,
            destructuredPropNames: destructuredPropNames,
            jsxEnabled: jsxEnabled,
            dataAttributePrefix: dataAttributePrefix,
            templateCompilerOptions: templateCompilerOptions,
            sourceDescription: sourceDescription
        )
    }

    func with(jsxEnabled: Bool) -> Self {
        VueCompilerOptions.Options(
            target: target,
            strictTemplates: strictTemplates,
            isCustomElement: isCustomElement,
            destructuredPropNames: destructuredPropNames,
            jsxEnabled: jsxEnabled,
            dataAttributePrefix: dataAttributePrefix,
            templateCompilerOptions: templateCompilerOptions,
            sourceDescription: sourceDescription
        )
    }

    func with(sourceDescription: String) -> Self {
        VueCompilerOptions.Options(
            target: target,
            strictTemplates: strictTemplates,
            isCustomElement: isCustomElement,
            destructuredPropNames: destructuredPropNames,
            jsxEnabled: jsxEnabled,
            dataAttributePrefix: dataAttributePrefix,
            templateCompilerOptions: templateCompilerOptions,
            sourceDescription: sourceDescription
        )
    }
}
