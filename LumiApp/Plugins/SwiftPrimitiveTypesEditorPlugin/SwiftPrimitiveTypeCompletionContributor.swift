import Foundation

/// Swift 原生类型补全贡献者
/// 在类型上下文（例如 `let id: In`）时优先给出 Int/Int8/Int32 等建议。
@MainActor
final class SwiftPrimitiveTypeCompletionContributor: SuperEditorCompletionContributor {
    let id = "builtin.swift.primitive-types"

    private static let primitiveTypes: [EditorCompletionSuggestion] = [
        .init(label: "Int", insertText: "Int", detail: "Swift Standard Type", priority: 1000),
        .init(label: "Int8", insertText: "Int8", detail: "Swift Standard Type", priority: 995),
        .init(label: "Int16", insertText: "Int16", detail: "Swift Standard Type", priority: 994),
        .init(label: "Int32", insertText: "Int32", detail: "Swift Standard Type", priority: 993),
        .init(label: "Int64", insertText: "Int64", detail: "Swift Standard Type", priority: 992),
        .init(label: "UInt", insertText: "UInt", detail: "Swift Standard Type", priority: 991),
        .init(label: "UInt8", insertText: "UInt8", detail: "Swift Standard Type", priority: 990),
        .init(label: "UInt16", insertText: "UInt16", detail: "Swift Standard Type", priority: 989),
        .init(label: "UInt32", insertText: "UInt32", detail: "Swift Standard Type", priority: 988),
        .init(label: "UInt64", insertText: "UInt64", detail: "Swift Standard Type", priority: 987),
        .init(label: "Float", insertText: "Float", detail: "Swift Standard Type", priority: 980),
        .init(label: "Double", insertText: "Double", detail: "Swift Standard Type", priority: 979),
        .init(label: "Bool", insertText: "Bool", detail: "Swift Standard Type", priority: 978),
        .init(label: "String", insertText: "String", detail: "Swift Standard Type", priority: 977)
    ]

    func provideSuggestions(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        guard context.languageId.lowercased() == "swift" else { return [] }
        guard context.isTypeContext else { return [] }
        let prefix = context.prefix.lowercased()
        guard !prefix.isEmpty else { return Self.primitiveTypes }
        return Self.primitiveTypes.filter { $0.label.lowercased().hasPrefix(prefix) }
    }
}
