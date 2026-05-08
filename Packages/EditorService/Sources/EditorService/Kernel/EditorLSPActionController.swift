import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
final class EditorLSPActionController: EditorLSPActionProviding {
    func languageID(for ext: String) -> String? {
        EditorLSPActionPolicy.languageID(forFileExtension: ext)
    }

    // MARK: - EditorLSPActionProviding conformance

    func jumpKindStatusMessage(_ kind: EditorLSPActionJumpKind) -> String {
        switch EditorLSPActionPolicy.statusMessageKey(for: kind) {
        case .findingDefinition:
            return String(localized: "Finding definition...", table: EditorHostEnvironment.current.localizationTable)
        case .findingDeclaration:
            return String(localized: "Finding declaration...", table: EditorHostEnvironment.current.localizationTable)
        case .findingTypeDefinition:
            return String(localized: "Finding type definition...", table: EditorHostEnvironment.current.localizationTable)
        case .findingImplementation:
            return String(localized: "Finding implementation...", table: EditorHostEnvironment.current.localizationTable)
        }
    }

    func referenceResults(
        from locations: [Location],
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?,
        previewLine: (URL, Int) -> String?
    ) -> [ReferenceResult] {
        EditorLSPActionPolicy.referenceResults(
            from: locations,
            currentFileURL: currentFileURL,
            relativeFilePath: relativeFilePath,
            projectRootPath: projectRootPath,
            previewLine: previewLine
        )
    }

    func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK", table: EditorHostEnvironment.current.localizationTable))
        alert.runModal()
    }

    func previewLine(from url: URL, at lineNumber: Int) -> String? {
        guard lineNumber > 0 else { return nil }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        guard lineNumber - 1 < lines.count else { return nil }
        return lines[lineNumber - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
