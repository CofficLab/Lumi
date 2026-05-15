import Foundation

/// Vue Props 定义模型
///
/// 从 `<script setup>` 或 Options API 的 `props` 选项中解析 Props 定义，
/// 包含名称、类型、默认值、是否必填等信息。
struct VuePropDefinition: Sendable {
    /// Prop 名称
    let name: String

    /// 类型（如 "String", "Number", "Boolean", "Array", "Object", "Function" 等）
    let type: PropType

    /// 是否必填
    let isRequired: Bool

    /// 默认值（原始文本表示）
    let defaultValue: String?

    /// 验证器描述（如果存在 validator）
    let hasValidator: Bool

    /// 来源
    let source: Source

    enum Source: String, Sendable {
        case defineProps       // defineProps<{...}>()
        case withDefaults     // withDefaults(defineProps<{...}>(), { ... })
        case optionsAPI       // props: { ... }
    }

    /// Prop 类型
    enum PropType: String, Sendable, CaseIterable {
        case string = "String"
        case number = "Number"
        case boolean = "Boolean"
        case array = "Array"
        case object = "Object"
        case function = "Function"
        case date = "Date"
        case symbol = "Symbol"
        case any = "Any"

        /// TypeScript 类型关键字到 PropType 的映射
        static func fromTypeScript(_ tsType: String) -> PropType {
            let normalized = tsType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalized {
            case "string": return .string
            case "number": return .number
            case "boolean": return .boolean
            case "array", "any[]": return .array
            case "object", "record", "record<string, any>": return .object
            case "function", "(...args: any[]) => void", "() => void": return .function
            case "date": return .date
            case "symbol": return .symbol
            default: return .any
            }
        }
    }

    // MARK: - 解析

    /// 从 Script 内容中解析 Props 定义
    ///
    /// 支持三种语法：
    /// 1. `defineProps<{ name: string, count?: number }>()`
    /// 2. `withDefaults(defineProps<{ ... }>(), { name: 'hello' })`
    /// 3. `defineProps(['name', 'count'])`  (数组形式)
    /// 4. Options API: `props: { name: { type: String, required: true } }`
    ///
    /// - Parameters:
    ///   - content: Script 区块内容
    ///   - isSetup: 是否为 `<script setup>`
    /// - Returns: Props 定义列表
    static func parse(from content: String, isSetup: Bool) -> [VuePropDefinition] {
        var props: [VuePropDefinition] = []

        // 1. TypeScript 泛型形式: defineProps<{ ... }>()
        if let tsProps = parseTypeScriptGeneric(from: content) {
            props = tsProps
        }

        // 2. 数组形式: defineProps(['xxx', 'yyy'])
        if props.isEmpty, let arrayProps = parseArrayForm(from: content) {
            props = arrayProps
        }

        // 3. Options API: props: { ... }
        if props.isEmpty, !isSetup, let optionsProps = parseOptionsAPI(from: content) {
            props = optionsProps
        }

        // 4. 合并 withDefaults 的默认值
        if !props.isEmpty {
            let defaults = parseWithDefaults(from: content)
            if !defaults.isEmpty {
                props = props.map { prop in
                    if let def = defaults[prop.name] {
                        return VuePropDefinition(
                            name: prop.name,
                            type: prop.type,
                            isRequired: prop.isRequired,
                            defaultValue: def,
                            hasValidator: prop.hasValidator,
                            source: .withDefaults
                        )
                    }
                    return prop
                }
            }
        }

        return props
    }

    // MARK: - TypeScript 泛型解析

    /// 解析 defineProps<{ name: string, count?: number }>()
    private static func parseTypeScriptGeneric(from content: String) -> [VuePropDefinition]? {
        // 查找 defineProps<{ ... }>
        let pattern = #"defineProps\s*<\s*\{([^}]*)\}\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let genericContent = String(content[range])
        var props: [VuePropDefinition] = []

        let lines = genericContent.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // 匹配 "name: string" 或 "count?: number"
            let linePattern = #"^(\w+)(\??)\s*:\s*(.+)$"#
            guard let lineRegex = try? NSRegularExpression(pattern: linePattern, options: []),
                  let lineMatch = lineRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  let nameRange = Range(lineMatch.range(at: 1), in: trimmed) else {
                continue
            }

            let propName = String(trimmed[nameRange])
            let isOptional = Range(lineMatch.range(at: 2), in: trimmed) != nil
            let typeStr: String
            if let typeRange = Range(lineMatch.range(at: 3), in: trimmed) {
                typeStr = String(trimmed[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                typeStr = "any"
            }

            props.append(VuePropDefinition(
                name: propName,
                type: .fromTypeScript(typeStr),
                isRequired: !isOptional,
                defaultValue: nil,
                hasValidator: false,
                source: .defineProps
            ))
        }

        return props.isEmpty ? nil : props
    }

    // MARK: - 数组形式解析

    /// 解析 defineProps(['xxx', 'yyy'])
    private static func parseArrayForm(from content: String) -> [VuePropDefinition]? {
        let pattern = #"defineProps\s*\(\s*\[([^\]]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let arrayContent = String(content[range])
        var props: [VuePropDefinition] = []

        let names = arrayContent.split(separator: ",").compactMap { part -> String? in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "'\"`"))
            return cleaned.isEmpty ? nil : cleaned
        }

        for name in names {
            props.append(VuePropDefinition(
                name: name,
                type: .any,
                isRequired: false,
                defaultValue: nil,
                hasValidator: false,
                source: .defineProps
            ))
        }

        return props.isEmpty ? nil : props
    }

    // MARK: - Options API 解析

    /// 解析 Options API 形式的 props
    private static func parseOptionsAPI(from content: String) -> [VuePropDefinition]? {
        // 简单匹配 props: { name: { type: String, ... } } 或 props: ['xxx']
        // 数组形式
        let arrayPattern = #"props\s*:\s*\[([^\]]*)\]"#
        if let regex = try? NSRegularExpression(pattern: arrayPattern, options: []),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let arrayContent = String(content[range])
            var props: [VuePropDefinition] = []
            let names = arrayContent.split(separator: ",").compactMap { part -> String? in
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "'\"`"))
                return cleaned.isEmpty ? nil : cleaned
            }
            for name in names {
                props.append(VuePropDefinition(
                    name: name,
                    type: .any,
                    isRequired: false,
                    defaultValue: nil,
                    hasValidator: false,
                    source: .optionsAPI
                ))
            }
            return props.isEmpty ? nil : props
        }

        return nil
    }

    // MARK: - withDefaults 解析

    /// 解析 withDefaults(defineProps<...>(), { name: 'hello', count: 0 })
    private static func parseWithDefaults(from content: String) -> [String: String] {
        let pattern = #"withDefaults\s*\(.*?,\s*\{([^}]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return [:]
        }

        let defaultsContent = String(content[range])
        var defaults: [String: String] = [:]

        // 匹配 name: 'value' 或 name: () => xxx
        let entryPattern = #"(\w+)\s*:\s*(?:\(\)\s*=>\s*)?([^,}\n]+)"#
        guard let entryRegex = try? NSRegularExpression(pattern: entryPattern, options: []) else { return [:] }

        let nsRange = NSRange(defaultsContent.startIndex..., in: defaultsContent)
        for entryMatch in entryRegex.matches(in: defaultsContent, range: nsRange) {
            if let nameRange = Range(entryMatch.range(at: 1), in: defaultsContent),
               let valueRange = Range(entryMatch.range(at: 2), in: defaultsContent) {
                let name = String(defaultsContent[nameRange])
                let value = String(defaultsContent[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                defaults[name] = value
            }
        }

        return defaults
    }
}
