import Foundation

@MainActor
final class XcodePlistHoverContributor: EditorHoverContributor {
    let id = "builtin.xcode.plist-hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        let runtimeContext = XcodeProjectEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL,
              let markdown = PlistEditing.hoverMarkdown(for: context.symbol, fileURL: fileURL) else {
            return []
        }
        return [.init(markdown: markdown, priority: 180, dedupeKey: "plist:\(context.symbol.lowercased())")]
    }
}
