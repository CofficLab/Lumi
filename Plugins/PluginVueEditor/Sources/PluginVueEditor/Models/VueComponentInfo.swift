import Foundation

/// Vue 组件元数据模型
///
/// 封装从 `.vue` 文件中提取的组件信息，包括名称、Props、Emits、Slots 等。
/// 供大纲视图、组件补全、重命名等功能使用。
struct VueComponentInfo: Sendable {
    /// 组件文件路径
    let filePath: String

    /// 组件名（PascalCase）
    let name: String

    /// 组件的 kebab-case 名称
    var kebabName: String {
        VueProjectScanner.pascalToKebab(name)
    }

    /// Props 列表
    let props: [VuePropDefinition]

    /// Emits 列表
    let emits: [EmitDefinition]

    /// Slots 列表
    let slots: [SlotDefinition]

    /// 是否使用了 `<script setup>`
    let isScriptSetup: Bool

    /// Vue 版本（由 VueVersionDetector 检测）
    let vueVersion: VueVersionDetector.VueVersion

    /// 区块列表
    let blocks: [SFCBlock]

    /// 组件 display name（如果有 `defineOptions({ name: 'Xxx' })`）
    let displayName: String?

    /// 是否为默认导出组件
    let isDefaultExport: Bool

    // MARK: - 子模型

    /// Emit 定义
    struct EmitDefinition: Sendable {
        /// 事件名
        let name: String

        /// 事件参数类型描述（如 "payload: string"）
        let parameters: [String]

        /// 来源（defineEmits / $emit）
        let source: Source

        enum Source: String, Sendable {
            case defineEmits
            case dollarEmit
            case inferred
        }
    }

    /// Slot 定义
    struct SlotDefinition: Sendable {
        /// 插槽名
        let name: String

        /// 是否为默认插槽
        let isDefault: Bool

        /// 插槽描述（来自注释）
        let description: String?

        /// 插槽 props（作用域插槽）
        let props: [String]
    }

    // MARK: - 解析

    /// 从 `.vue` 文件内容中提取组件信息
    ///
    /// - Parameters:
    ///   - content: .vue 文件完整内容
    ///   - filePath: 文件路径
    ///   - vueVersion: 检测到的 Vue 版本
    /// - Returns: 组件元数据
    static func parse(
        from content: String,
        filePath: String,
        vueVersion: VueVersionDetector.VueVersion
    ) -> VueComponentInfo {
        let blocks = SFCBlock.parse(from: content)
        let fileName = URL(fileURLWithPath: filePath)
            .deletingPathExtension()
            .lastPathComponent
        let componentName = VueProjectScanner.fileNameToComponentName(fileName)

        let scriptBlock = SFCBlock.find(type: .script, in: blocks)
        let templateBlock = SFCBlock.find(type: .template, in: blocks)

        let isScriptSetup = scriptBlock?.isSetup ?? false

        // 解析 Props
        let props: [VuePropDefinition]
        if let scriptContent = scriptBlock?.content {
            props = VuePropDefinition.parse(from: scriptContent, isSetup: isScriptSetup)
        } else {
            props = []
        }

        // 解析 Emits
        let emits = parseEmits(from: scriptBlock?.content)

        // 解析 Slots
        let slots = parseSlots(from: templateBlock?.content)

        // 解析 display name
        let displayName = parseDisplayName(from: scriptBlock?.content)

        return VueComponentInfo(
            filePath: filePath,
            name: componentName,
            props: props,
            emits: emits,
            slots: slots,
            isScriptSetup: isScriptSetup,
            vueVersion: vueVersion,
            blocks: blocks,
            displayName: displayName,
            isDefaultExport: true
        )
    }

    // MARK: - Emits 解析

    private static func parseEmits(from scriptContent: String?) -> [EmitDefinition] {
        guard let content = scriptContent else { return [] }
        var emits: [EmitDefinition] = []

        // 匹配 defineEmits(['xxx', 'yyy'])
        let arrayPattern = #"defineEmits\s*\(\s*\[([^\]]*)\]"#
        if let regex = try? NSRegularExpression(pattern: arrayPattern, options: []),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let arrayContent = String(content[range])
            let names = arrayContent
                .split(separator: ",")
                .compactMap { part -> String? in
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "'\"`"))
                    return cleaned.isEmpty ? nil : cleaned
                }
            for name in names {
                emits.append(EmitDefinition(name: name, parameters: [], source: .defineEmits))
            }
        }

        // 匹配 defineEmits({ xxx: ... }) 的对象形式
        if emits.isEmpty {
            let objectPattern = #"defineEmits\s*\(\s*\{([^}]*)\}"#
            if let regex = try? NSRegularExpression(pattern: objectPattern, options: []),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let objectContent = String(content[range])
                let lines = objectContent.components(separatedBy: ",")
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let name = parseObjectEmitName(from: trimmed),
                       !emits.contains(where: { $0.name == name }) {
                        emits.append(EmitDefinition(name: name, parameters: [], source: .defineEmits))
                    }
                }
            }
        }

        return emits
    }

    private static func parseObjectEmitName(from entry: String) -> String? {
        let patterns = [
            #"^\s*["'`]([^"'`]+)["'`]\s*:"#,
            #"^\s*([A-Za-z_$][\w$]*)\s*:"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: entry, range: NSRange(entry.startIndex..., in: entry)),
                  let range = Range(match.range(at: 1), in: entry) else {
                continue
            }
            let name = String(entry[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }

        return nil
    }

    // MARK: - Slots 解析

    private static func parseSlots(from templateContent: String?) -> [SlotDefinition] {
        guard let content = templateContent else { return [] }
        var slots: [SlotDefinition] = []
        var seenNames: Set<String> = []

        // 匹配 <slot /> 或 <slot name="xxx">
        let pattern = #"<slot(?:\s+name\s*=\s*["']([^"']+)["'])?[^>]*\/?\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let nsRange = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: nsRange) {
            let name: String
            if let nameRange = Range(match.range(at: 1), in: content) {
                name = String(content[nameRange])
            } else {
                name = "default"
            }

            if seenNames.contains(name) { continue }
            seenNames.insert(name)

            // 简单检测作用域插槽 props: <slot :item="item">
            let fullMatch = String(content[Range(match.range, in: content)!])
            let hasProps = hasScopedSlotProps(in: fullMatch)

            slots.append(SlotDefinition(
                name: name,
                isDefault: name == "default",
                description: nil,
                props: hasProps ? ["(scoped)"] : []
            ))
        }

        // 确保默认插槽存在
        if !slots.contains(where: { $0.isDefault }) && !content.contains("<slot") {
            // 没有显式 slot 标签时，隐含一个默认插槽
        }

        return slots
    }

    static func hasScopedSlotProps(in slotTag: String) -> Bool {
        let patterns = [
            #"\s:[A-Za-z_][\w-]*\s*="#,
            #"\sv-bind(?::[A-Za-z_][\w-]*)?\s*="#,
        ]

        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: slotTag, range: NSRange(slotTag.startIndex..., in: slotTag)) != nil
        }
    }

    // MARK: - Display Name 解析

    private static func parseDisplayName(from scriptContent: String?) -> String? {
        guard let content = scriptContent else { return nil }

        // 匹配 defineOptions({ name: 'Xxx' })
        let pattern = #"defineOptions\s*\(\s*\{[^}]*name\s*:\s*['"]([^'"]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        return String(content[range])
    }
}
