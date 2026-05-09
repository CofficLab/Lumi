import Foundation
import XcodeKit
import os

@MainActor
final class XcodePackageManifestHoverContributor: SuperEditorHoverContributor {
    let id = "builtin.xcode.package-manifest-hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL,
              fileURL.lastPathComponent == "Package.swift" else {
            return []
        }

        let line = context.line
        let character = context.character
        let content = runtimeContext.currentContent

        // Markdown 生成移到后台线程（涉及语法解析）
        let markdown: String? = await Task.detached(priority: .userInitiated) {
            PackageManifestSyntax.hoverMarkdown(
                line: line,
                character: character,
                in: content
            )
        }.value

        guard let markdown else { return [] }

        if XcodePluginLog.verbose {
            XcodePluginLog.logger.info("📦 XcodePackageManifestHoverContributor | Hover 生成完成，line：\(line)")
        }

        return [
            .init(
                markdown: markdown,
                priority: 170,
                dedupeKey: "package-manifest:\(line):\(character)"
            )
        ]
    }
}
