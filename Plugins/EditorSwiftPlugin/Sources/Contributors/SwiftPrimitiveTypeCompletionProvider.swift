import Foundation
import KernelLumi

/// Swift 原生类型补全 Provider（契约 V2 §10）。
///
/// 在类型上下文（例如 `let id: In`）时优先给出 Int/Int8/Int32 等建议；
/// 与 LSP 补全由宿主 resolver 合并去重（§9.5）。
public final class SwiftPrimitiveTypeCompletionProvider: EditorCompletionProvider, @unchecked Sendable {
    public let id = "builtin.swift.primitive-types"

    public init() {}

    private static let primitiveTypes: [EditorCompletionItem] = [
        .init(label: "Int", kind: .keyword, priority: 1000),
        .init(label: "Int8", kind: .keyword, priority: 995),
        .init(label: "Int16", kind: .keyword, priority: 994),
        .init(label: "Int32", kind: .keyword, priority: 993),
        .init(label: "Int64", kind: .keyword, priority: 992),
        .init(label: "UInt", kind: .keyword, priority: 991),
        .init(label: "UInt8", kind: .keyword, priority: 990),
        .init(label: "UInt16", kind: .keyword, priority: 989),
        .init(label: "UInt32", kind: .keyword, priority: 988),
        .init(label: "UInt64", kind: .keyword, priority: 987),
        .init(label: "Float", kind: .keyword, priority: 980),
        .init(label: "Double", kind: .keyword, priority: 979),
        .init(label: "Bool", kind: .keyword, priority: 978),
        .init(label: "String", kind: .keyword, priority: 977),
    ]

    public func completions(for request: EditorCompletionRequest) async -> [EditorCompletionItem] {
        guard request.context.languageID.lowercased() == "swift" else { return [] }
        guard request.isTypeContext else { return [] }
        let prefix = request.prefix.lowercased()
        guard !prefix.isEmpty else { return Self.primitiveTypes }
        return Self.primitiveTypes.filter { $0.label.lowercased().hasPrefix(prefix) }
    }
}
