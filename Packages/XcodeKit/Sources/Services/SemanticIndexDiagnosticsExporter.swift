import Foundation

public struct SemanticIndexDiagnosticsPackage: Sendable {
    public var text: String
    public var suggestedFilename: String
}

public enum SemanticIndexDiagnosticsExporter {
    public static func makePackage(
        workspacePath: String,
        store: XcodeBuildServerStore,
        preflight: XcodeBuildServerLocator.PreflightResult,
        semanticIndexStatus: XcodeSemanticIndexStatus,
        capabilityLevel: SemanticCapabilityLevel
    ) -> SemanticIndexDiagnosticsPackage {
        let manifest = store.loadManifest(forWorkspace: workspacePath)
        let compileURL = store.compileDatabaseURL(forWorkspace: workspacePath)
        let compileEntries = compileEntryCount(at: compileURL)
        let logURL = store.ensureDirectory(forWorkspace: workspacePath)
            .appendingPathComponent("semantic-index-build.log")
        let logTail = logTailText(from: logURL)

        var lines: [String] = []
        lines.append("Lumi EditorSwift Diagnostics")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Workspace: \(workspacePath)")
        lines.append("Semantic Status: \(semanticIndexStatus.displayDescription)")
        lines.append("Capability Level: \(capabilityLevel.displayName)")
        lines.append("Xcode: \(preflight.xcodeVersion ?? "unknown")")
        lines.append("xcode-build-server: \(preflight.xcodeBuildServerVersion ?? "unknown") @ \(preflight.xcodeBuildServerPath ?? "missing")")
        if let manifest {
            lines.append("Manifest scheme: \(manifest.scheme)")
            lines.append("Manifest configuration: \(manifest.configuration)")
            lines.append("Manifest destination: \(manifest.destination)")
            lines.append("Manifest builtAt: \(manifest.builtAt?.description ?? "nil")")
            lines.append("Manifest compile entries: \(manifest.compileDatabase?.entryCount ?? 0)")
        }
        lines.append("Compile DB entries on disk: \(compileEntries)")
        if !preflight.issues.isEmpty {
            lines.append("Preflight issues:")
            preflight.issues.forEach { lines.append("  - \($0)") }
        }
        if let logTail, !logTail.isEmpty {
            lines.append("")
            lines.append("Build log tail:")
            lines.append(logTail)
        }

        let filename = "LumiDiagnostics-\(URL(fileURLWithPath: workspacePath).lastPathComponent)-\(Int(Date().timeIntervalSince1970)).txt"
        return SemanticIndexDiagnosticsPackage(
            text: lines.joined(separator: "\n"),
            suggestedFilename: filename
        )
    }

    @discardableResult
    public static func exportToDownloads(_ package: SemanticIndexDiagnosticsPackage) -> URL? {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        let destination = downloads.appendingPathComponent(package.suggestedFilename)
        do {
            try package.text.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        } catch {
            return nil
        }
    }

    private static func compileEntryCount(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return 0
        }
        return array.count
    }

    private static func logTailText(from url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
            .split(whereSeparator: \.isNewline)
            .suffix(40)
            .joined(separator: "\n")
    }
}
