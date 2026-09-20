import Foundation
import LanguageServerProtocol

/// Filters SourceKit diagnostics that are expected before Xcode build context is ready.
enum LSPDiagnosticBuildContextPolicy {
    // MARK: - 缓存

    /// 按 buildServerPath + mtime 缓存已解析的 module_names
    nonisolated(unsafe)
    private static var moduleNamesCache: [String: (mtime: TimeInterval, modules: Set<String>)] = [:]

    /// 获取缓存的 module names（带 mtime 检查）
    private static func getCachedModuleNames(for compileDatabasePath: String, currentMtime: TimeInterval) -> Set<String>? {
        guard let cached = moduleNamesCache[compileDatabasePath],
              cached.mtime == currentMtime else {
            return nil
        }
        return cached.modules
    }

    /// 设置缓存
    private static func setCachedModuleNames(_ modules: Set<String>, for compileDatabasePath: String, mtime: TimeInterval) {
        moduleNamesCache[compileDatabasePath] = (mtime: mtime, modules: modules)
    }
    static func isNoSuchModuleDiagnostic(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("no such module")
    }

    static func noSuchModuleName(from message: String) -> String? {
        guard isNoSuchModuleDiagnostic(message),
              let start = message.firstIndex(of: "'") else {
            return nil
        }
        let nameStart = message.index(after: start)
        guard let end = message[nameStart...].firstIndex(of: "'") else {
            return nil
        }
        let name = message[nameStart..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func shouldPublishDiagnostic(
        _ diagnostic: Diagnostic,
        buildServerPathAvailable: Bool,
        knownModuleNames: Set<String> = []
    ) -> Bool {
        guard let missingModuleName = noSuchModuleName(from: diagnostic.message) else {
            return true
        }
        guard buildServerPathAvailable else { return false }
        return !knownModuleNames.contains(missingModuleName)
    }

    static func filteredDiagnostics(
        _ diagnostics: [Diagnostic],
        buildServerPathAvailable: Bool,
        knownModuleNames: Set<String> = []
    ) -> [Diagnostic] {
        diagnostics.filter {
            shouldPublishDiagnostic(
                $0,
                buildServerPathAvailable: buildServerPathAvailable,
                knownModuleNames: knownModuleNames
            )
        }
    }

    static func knownModuleNames(inCompileDatabaseForBuildServerPath buildServerPath: String) -> Set<String> {
        let compileDatabasePath = (buildServerPath as NSString)
            .deletingLastPathComponent
            .appending("/.compile")

        // 获取文件 mtime
        let fileURL = URL(fileURLWithPath: compileDatabasePath)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: compileDatabasePath),
              let mtime = attributes[.modificationDate] as? Date else {
            return []
        }
        let mtimeInterval = mtime.timeIntervalSince1970

        // 缓存命中检查
        if let cached = getCachedModuleNames(for: compileDatabasePath, currentMtime: mtimeInterval) {
            return cached
        }

        // 读取并解析
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let modules = Set(entries.compactMap { entry in
            (entry["module_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })

        // 更新缓存
        setCachedModuleNames(modules, for: compileDatabasePath, mtime: mtimeInterval)

        return modules
    }
}
