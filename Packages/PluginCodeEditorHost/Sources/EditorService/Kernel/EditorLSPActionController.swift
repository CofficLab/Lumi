import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
final class EditorLSPActionController: EditorLSPActionProviding {
    /// 文件行缓存，按 URL + mtime 缓存已解析的行数组
    private var lineCache: [URL: (lines: [String], mtime: Date)] = [:]

    func languageID(for ext: String) -> String? {
        EditorLSPActionPolicy.languageID(forFileExtension: ext)
    }

    // MARK: - EditorLSPActionProviding conformance

    func jumpKindStatusMessage(_ kind: EditorLSPActionJumpKind) -> String {
        switch EditorLSPActionPolicy.statusMessageKey(for: kind) {
        case .findingDefinition:
            return String(localized: "Finding definition...", bundle: .module)
        case .findingDeclaration:
            return String(localized: "Finding declaration...", bundle: .module)
        case .findingTypeDefinition:
            return String(localized: "Finding type definition...", bundle: .module)
        case .findingImplementation:
            return String(localized: "Finding implementation...", bundle: .module)
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
        alert.addButton(withTitle: String(localized: "OK", bundle: .module))
        alert.runModal()
    }

    func previewLine(from url: URL, at lineNumber: Int) -> String? {
        guard lineNumber > 0 else { return nil }

        // 检查缓存是否有效
        let currentMtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let cached = lineCache[url], cached.mtime == currentMtime {
            guard lineNumber - 1 < cached.lines.count else { return nil }
            return cached.lines[lineNumber - 1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 缓存未命中，读取文件并解析
        guard let content = try? EditorTextFileReader.read(url) else { return nil }
        let lines = content.components(separatedBy: .newlines)

        // 更新缓存
        lineCache[url] = (lines: lines, mtime: currentMtime ?? Date())

        guard lineNumber - 1 < lines.count else { return nil }
        return lines[lineNumber - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
