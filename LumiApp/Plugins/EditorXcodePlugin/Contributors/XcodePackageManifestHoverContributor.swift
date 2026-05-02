import Foundation

@MainActor
final class XcodePackageManifestHoverContributor: SuperEditorHoverContributor {
    let id = "builtin.xcode.package-manifest-hover"

    func provideHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] {
        let runtimeContext = SuperEditorRuntimeContext.shared
        guard let fileURL = runtimeContext.currentFileURL,
              fileURL.lastPathComponent == "Package.swift",
              let markdown = PackageManifestSyntax.hoverMarkdown(
                line: context.line,
                character: context.character,
                in: runtimeContext.currentContent
              ) else {
            return []
        }

        return [
            .init(
                markdown: markdown,
                priority: 170,
                dedupeKey: "package-manifest:\(context.line):\(context.character)"
            )
        ]
    }
}
