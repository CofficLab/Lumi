import Foundation
import KernelLumi

/// Swift 关键字 Hover Provider（契约 V2 §10）。
///
/// 为常用关键字提供内置文档；与 LSP Hover 由宿主 resolver 聚合展示（§9.5）。
public final class SwiftKeywordHoverProvider: EditorHoverProvider, @unchecked Sendable {
    public let id = "builtin.swift.keyword-hover"

    public init() {}

    private static let docs: [String: String] = [
        "async": """
`async` marks a function that can suspend while awaiting asynchronous work.
""",
        "await": """
`await` waits for an `async` function to complete at a suspension point.
""",
        "actor": """
`actor` defines a reference type with isolated mutable state for data-race safety.
""",
        "struct": """
`struct` defines a value type. Copies create independent values.
""",
        "class": """
`class` defines a reference type. Instances are shared by reference.
""",
        "some": """
`some` denotes an opaque result type: a specific type hidden behind a protocol.
""",
        "any": """
`any` denotes an existential type: a box holding any conforming type.
""",
    ]

    public func hover(for request: EditorHoverRequest) async -> [EditorHoverSection] {
        guard request.context.languageID.lowercased() == "swift" else { return [] }
        let key = request.symbol.lowercased()
        guard let markdown = Self.docs[key] else { return [] }
        return [EditorHoverSection(markdown: markdown, priority: 100, dedupeKey: "swift.keyword.\(key)")]
    }
}
