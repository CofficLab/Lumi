import Foundation
import XcodeKit
import os

@MainActor
final class XcodePlistHoverContributor: SuperEditorHoverContributor {
    let id = "builtin.xcode.plist-hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL else { return [] }

        let symbol = context.symbol

        // Markdown 生成移到后台线程（可能涉及文件读取和解析）
        let markdown: String? = await Task.detached(priority: .userInitiated) {
            PlistEditing.hoverMarkdown(for: symbol, fileURL: fileURL)
        }.value

        guard let markdown else { return [] }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("💬 XcodePlistHoverContributor | Hover 生成完成，symbol：\(symbol)")
        }

        return [.init(markdown: markdown, priority: 180, dedupeKey: "plist:\(symbol.lowercased())")]
    }
}
