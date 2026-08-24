import Foundation
import KernelLumi

/// Swift 选区 Code Action Provider（契约 V2 §10）。
///
/// 有选区时提供：
/// - 「Wrap Selection with print(...)」
/// - 「Wrap Selection in #if DEBUG」
///
/// 动作以 URI 寻址文本编辑返回（`EditorURITextEdit`），
/// 由宿主解析为已打开文档后经 `documents.apply` 应用（§16 编辑闭环）。
public final class SwiftSelectionCodeActionProvider: EditorCodeActionProvider, @unchecked Sendable {
    public let id = "builtin.swift.selection-actions"

    public init() {}

    public func codeActions(for request: EditorCodeActionRequest) async -> [EditorCodeActionItem] {
        guard request.context.languageID.lowercased() == "swift" else { return [] }
        guard let uri = request.context.uri else { return [] }
        guard let selected = request.selectedText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !selected.isEmpty,
            !request.range.isEmpty else {
            return []
        }
        let selection = request.range.normalized
        return [
            EditorCodeActionItem(
                id: "builtin.swift.wrap-print",
                title: LumiPluginLocalization.string("Wrap Selection with print(...)", bundle: .module),
                kind: .refactor,
                priority: 120,
                textEdits: [
                    EditorURITextEdit(
                        uri: uri,
                        edits: [
                            EditorTextEdit(
                                range: selection,
                                newText: "print(\(selected))"
                            )
                        ]
                    )
                ]
            ),
            EditorCodeActionItem(
                id: "builtin.swift.wrap-debug",
                title: LumiPluginLocalization.string("Wrap Selection in #if DEBUG", bundle: .module),
                kind: .refactor,
                priority: 110,
                textEdits: [
                    EditorURITextEdit(
                        uri: uri,
                        edits: [
                            EditorTextEdit(
                                range: selection,
                                newText: "#if DEBUG\n\(selected)\n#endif"
                            )
                        ]
                    )
                ]
            ),
        ]
    }
}
