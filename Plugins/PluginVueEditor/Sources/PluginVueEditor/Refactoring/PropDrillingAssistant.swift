import Foundation
import os

/// Props 传递辅助工具
///
/// 在 Vue 组件树中追踪 Props 的传递路径，帮助开发者理解数据流向。
/// 当用户选中某个 Prop 或在 `<script setup>` 中查看 `defineProps` 时，
/// 可以快速了解该 Prop 的来源、传递链和类型。
struct PropDrillingAssistant: Sendable {
    nonisolated static let emoji = "🔗"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.prop-drilling"
    )

    // MARK: - Prop 传递路径

    /// Prop 传递节点
    struct PropPathNode: Sendable {
        /// 组件名
        let componentName: String

        /// 文件路径
        let filePath: String

        /// Prop 名
        let propName: String

        /// 传递类型
        let passType: PassType

        /// 行号（-1 表示无法定位）
        let lineNumber: Int
    }

    /// 传递类型
    enum PassType: String, Sendable {
        case defineProp        // defineProps 中声明
        case templateBinding   // :prop="value" 绑定
        case vModel            // v-model 双向绑定
        case emitUpdate        // emit('update:prop')
        case provide          // provide('key', value)
        case inject            // inject('key')
    }

    // MARK: - 分析结果

    /// Prop 传递分析结果
    struct PropAnalysis: Sendable {
        /// 目标 Prop 名
        let propName: String

        /// Prop 类型
        let propType: VuePropDefinition.PropType

        /// 传递路径（从祖先到当前组件）
        let path: [PropPathNode]

        /// 是否为 drilled prop（经过了 2+ 层传递）
        let isDrilled: Bool

        /// 建议（如建议使用 provide/inject 替代深层传递）
        let suggestions: [Suggestion]
    }

    /// 建议
    struct Suggestion: Sendable {
        let kind: SuggestionKind
        let message: String

        enum SuggestionKind: String, Sendable {
            case useProvideInject    // 建议使用 provide/inject
            case usePinia           // 建议使用 Pinia 状态管理
            case usePropsEmits      // 保持 props/emits（合理传递层级）
            case extractComposable  // 建议提取 composable
        }
    }

    // MARK: - 分析

    /// 分析指定组件中某个 Prop 的传递情况
    ///
    /// - Parameters:
    ///   - propName: Prop 名称
    ///   - componentInfo: 当前组件信息
    ///   - projectPath: 项目根目录
    /// - Returns: 分析结果
    static func analyze(
        propName: String,
        componentInfo: VueComponentInfo,
        projectPath: String
    ) -> PropAnalysis? {
        // 查找目标 Prop
        guard let prop = componentInfo.props.first(where: { $0.name == propName }) else {
            return nil
        }

        // 构建传递路径
        var path: [PropPathNode] = []

        // 当前组件中的声明
        path.append(PropPathNode(
            componentName: componentInfo.name,
            filePath: componentInfo.filePath,
            propName: propName,
            passType: .defineProp,
            lineNumber: -1
        ))

        // 检查是否有父组件传递此 Prop
        let parentUsages = findParentUsages(
            propName: propName,
            componentName: componentInfo.name,
            kebabName: componentInfo.kebabName,
            projectPath: projectPath
        )

        path.insert(contentsOf: parentUsages, at: 0)

        let isDrilled = path.count >= 3

        // 生成建议
        let suggestions = generateSuggestions(
            isDrilled: isDrilled,
            propType: prop.type,
            path: path
        )

        return PropAnalysis(
            propName: propName,
            propType: prop.type,
            path: path,
            isDrilled: isDrilled,
            suggestions: suggestions
        )
    }

    /// 扫描当前组件中所有可能被"穿透传递"的 Props
    ///
    /// - Parameter componentInfo: 组件信息
    /// - Returns: 被 drilling 的 Props 列表
    static func findDrilledProps(in componentInfo: VueComponentInfo) -> [PropAnalysis] {
        componentInfo.props.compactMap { prop in
            let analysis = analyze(
                propName: prop.name,
                componentInfo: componentInfo,
                projectPath: componentInfo.filePath
            )
            // 只返回真正被 drilling 的
            return analysis?.isDrilled == true ? analysis : nil
        }
    }

    // MARK: - Private

    /// 在项目中查找父组件如何使用此 Prop
    private static func findParentUsages(
        propName: String,
        componentName: String,
        kebabName: String,
        projectPath: String
    ) -> [PropPathNode] {
        var usages: [PropPathNode] = []

        // 扫描项目中所有 .vue 文件，查找使用该组件的地方
        let entries = VueProjectScanner.scan(projectPath: projectPath, maxResults: 200)

        for entry in entries {
            guard let content = try? VueTextFileIO.readContent(path: entry.path) else { continue }

            // 检查是否在 Template 中使用了该组件
            let pascalUsed = content.contains("<\(componentName)")
            let kebabUsed = content.contains("<\(kebabName)")
            guard pascalUsed || kebabUsed else { continue }

            // 检查是否传递了目标 prop
            let propBinding = ":\(propName)="
            let vModelBinding = "v-model\(propName == "modelValue" ? "" : ":\(propName)")="

            if content.contains(propBinding) {
                usages.append(PropPathNode(
                    componentName: entry.name,
                    filePath: entry.path,
                    propName: propName,
                    passType: .templateBinding,
                    lineNumber: -1
                ))
            }

            if content.contains(vModelBinding) {
                usages.append(PropPathNode(
                    componentName: entry.name,
                    filePath: entry.path,
                    propName: propName,
                    passType: .vModel,
                    lineNumber: -1
                ))
            }
        }

        return usages
    }

    /// 生成建议
    private static func generateSuggestions(
        isDrilled: Bool,
        propType: VuePropDefinition.PropType,
        path: [PropPathNode]
    ) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        if isDrilled {
            suggestions.append(Suggestion(
                kind: .useProvideInject,
                message: "Prop '\(path.first?.propName ?? "")' is passed through \(path.count) levels. Consider using provide/inject for deep prop drilling."
            ))

            if path.count >= 4 {
                suggestions.append(Suggestion(
                    kind: .usePinia,
                    message: "With \(path.count)+ levels of prop drilling, a state management solution (Pinia) may be more appropriate."
                ))
            }
        } else {
            suggestions.append(Suggestion(
                kind: .usePropsEmits,
                message: "Prop passing depth is reasonable (\(path.count) levels). Props/emits pattern is appropriate."
            ))
        }

        return suggestions
    }
}
