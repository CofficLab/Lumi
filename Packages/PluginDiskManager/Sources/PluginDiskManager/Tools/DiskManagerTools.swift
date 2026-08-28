import KitAgentTool
import Foundation

// MARK: - Tool Support

/// Disk Manager Agent 工具的共享支持逻辑（KernelCore 体系）。
///
/// 由旧版 `Plugins/DiskManagerPlugin/Sources/Tools/DiskManagerLumiTools.swift` 迁移而来，差异：
/// - 参数类型 `[String: LumiJSONValue]` → `[String: ToolArgument]`；
/// - 不再依赖 `KernelLumi`（移除 `kernel.checkCancellation()` / `kernel.isPathAllowed`）；
/// - 破坏性工具一律通过 `permissionRiskLevel == .high` 触发用户授权（等价旧版沙盒外路径拒绝）。
enum DiskManagerToolSupport {
    /// Format a byte count using the `KB/MB/GB` style from the Disk Manager UI.
    /// `ByteCountFormatter` is not `Sendable`, so we create one per call.
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func formatDate(_ date: Date?) -> String {
        guard let date else { return "unknown" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    /// Resolve a user-supplied scan path against the home directory.
    /// Returns the home directory when the input is missing/empty so the tool
    /// always has a usable root.
    static func resolveScanPath(_ raw: String?) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidate: String
        if trimmed.isEmpty || trimmed == "~" {
            candidate = home
        } else if trimmed.hasPrefix("~/") {
            candidate = home + String(trimmed.dropFirst())
        } else {
            candidate = (trimmed as NSString).expandingTildeInPath
        }
        return candidate
    }

    /// Measure the on-disk size of a path before deletion so cleanup tools can
    /// report how much space was actually freed. Uses `DiskService` to stay
    /// consistent with the rest of the plugin.
    static func sizeOfPath(_ path: String) async -> Int64 {
        await DiskService.shared.calculateSize(for: URL(fileURLWithPath: path))
    }

    // MARK: - Argument accessors（ToolArgument 版）

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func stringArray(_ arguments: [String: ToolArgument], _ key: String) -> [String]? {
        guard let array = arguments[key]?.value as? [Any] else { return nil }
        return array.compactMap { $0 as? String }
    }
}

// MARK: - Disk Usage

struct DiskUsageTool: SuperAgentTool {
    let name = "disk-manager.disk-usage"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Report total, used, and available capacity of the startup disk."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Disk Usage")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let usage = await DiskService.shared.getDiskUsage() else {
            return "Failed to read disk usage."
        }
        let percent = Int((usage.usedPercentage * 100).rounded())
        return """
        Disk usage (startup volume):
        - total: \(DiskManagerToolSupport.formatBytes(usage.total))
        - used: \(DiskManagerToolSupport.formatBytes(usage.used)) (\(percent)%)
        - available: \(DiskManagerToolSupport.formatBytes(usage.available))
        """
    }
}

// MARK: - Large Files

struct ScanLargeFilesTool: SuperAgentTool {
    let name = "disk-manager.scan-large-files"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Scan a directory for files larger than 50 MB and return the top entries by size. Defaults to the home directory."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": PluginDiskManagerLocalization.string(
                        "Directory to scan. Defaults to the home directory. Use a path returned by a previous scan."
                    ),
                ],
                "limit": [
                    "type": "integer",
                    "description": PluginDiskManagerLocalization.string(
                        "Maximum number of files to return (default 20, max 100)."
                    ),
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Scan Large Files")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = DiskManagerToolSupport.resolveScanPath(DiskManagerToolSupport.string(arguments, "path"))
        let limit = min(max(DiskManagerToolSupport.int(arguments, "limit") ?? 20, 1), 100)

        let files: [LargeFileEntry]
        do {
            files = try await LargeFilesService.shared.scanLargeFiles(atPath: path)
        } catch {
            return "Failed to scan large files at \(path): \(error.localizedDescription)"
        }
        guard !files.isEmpty else {
            return "No files larger than 50 MB were found under \(path)."
        }
        let shown = Array(files.prefix(limit))
        let header = "Large files under `\(path)` (showing \(shown.count) of \(files.count)):"
        let lines = shown.map { file in
            "- \(DiskManagerToolSupport.formatBytes(file.size)) · `\(file.path)` · modified \(DiskManagerToolSupport.formatDate(file.modificationDate)) · \(file.fileType.rawValue)"
        }
        return ([header] + lines).joined(separator: "\n")
    }
}

// MARK: - Directory Tree

struct ScanDirectoryTreeTool: SuperAgentTool {
    let name = "disk-manager.scan-directory-tree"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Analyze a directory tree and return the largest immediate subdirectories by size. Defaults to the home directory."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": PluginDiskManagerLocalization.string(
                        "Directory to analyze. Defaults to the home directory."
                    ),
                ],
                "limit": [
                    "type": "integer",
                    "description": PluginDiskManagerLocalization.string(
                        "Maximum number of top-level entries to return (default 20, max 100)."
                    ),
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Scan Directory Tree")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = DiskManagerToolSupport.resolveScanPath(DiskManagerToolSupport.string(arguments, "path"))
        let limit = min(max(DiskManagerToolSupport.int(arguments, "limit") ?? 20, 1), 100)

        let entries: [DirectoryEntry]
        do {
            entries = try await DirectoryTreeService.shared.scanDirectoryTree(atPath: path)
        } catch {
            return "Failed to analyze directory tree at \(path): \(error.localizedDescription)"
        }
        guard !entries.isEmpty else {
            return "No entries were found under \(path)."
        }
        let shown = Array(entries.prefix(limit))
        let header = "Top directories under `\(path)` (showing \(shown.count) of \(entries.count)):"
        let lines = shown.map { entry in
            let kind = entry.isDirectory ? "dir " : "file"
            return "- \(DiskManagerToolSupport.formatBytes(entry.size)) · \(kind) · `\(entry.path)`"
        }
        return ([header] + lines).joined(separator: "\n")
    }
}

// MARK: - System Caches

struct ScanCachesTool: SuperAgentTool {
    let name = "disk-manager.scan-caches"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Scan well-known system and developer caches (app cache, browser cache, developer caches, logs, trash) and group them by safety level."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Scan System Caches")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let categories = await CacheCleanerService.shared.scanCaches()
        guard !categories.isEmpty else {
            return "No cache categories were found."
        }
        let total = categories.reduce(Int64(0)) { $0 + $1.totalSize }
        var lines: [String] = [
            "Cache categories (total \(DiskManagerToolSupport.formatBytes(total))):",
        ]
        for category in categories {
            lines.append("")
            lines.append("### \(category.name) — \(category.safetyLevel.label) — \(DiskManagerToolSupport.formatBytes(category.totalSize))")
            lines.append(category.description)
            for item in category.paths.prefix(50) {
                lines.append("- \(DiskManagerToolSupport.formatBytes(item.size)) · `\(item.path)`")
            }
            if category.paths.count > 50 {
                lines.append("… and \(category.paths.count - 50) more")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct CleanCachesTool: SuperAgentTool {
    let name = "disk-manager.clean-caches"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Delete the given cache paths and report the space freed. Pass paths returned by scan-caches."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "paths": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": PluginDiskManagerLocalization.string(
                        "Cache directory paths to delete (from scan-caches)."
                    ),
                ],
            ],
            "required": ["paths"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = DiskManagerToolSupport.stringArray(arguments, "paths")?.count ?? 0
        return PluginDiskManagerLocalization.string("Delete \(count) cache path(s)")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let paths = DiskManagerToolSupport.stringArray(arguments, "paths")?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) else {
            return "Missing or invalid 'paths'. Provide an array of cache directory paths."
        }
        guard !paths.isEmpty else { return "No cache paths were provided." }

        // Measure each path before deletion so we can report the freed bytes,
        // since CacheCleanerService.cleanup sums `CachePath.size` itself.
        var cachePaths: [CachePath] = []
        for path in paths {
            let size = await DiskManagerToolSupport.sizeOfPath(path)
            cachePaths.append(CachePath(
                path: path,
                name: (path as NSString).lastPathComponent,
                description: "",
                size: size,
                fileCount: 0,
                canDelete: true
            ))
        }

        do {
            let freed = try await CacheCleanerService.shared.cleanup(paths: cachePaths)
            let perLine = paths.map { "- `\($0)`" }
            return ([
                "Cleaned \(paths.count) cache path(s); freed \(DiskManagerToolSupport.formatBytes(freed)).",
            ] + perLine).joined(separator: "\n")
        } catch {
            return "Failed to clean caches: \(error.localizedDescription)"
        }
    }
}

// MARK: - Xcode Caches

struct ScanXcodeCachesTool: SuperAgentTool {
    let name = "disk-manager.scan-xcode-caches"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Scan Xcode-related caches (DerivedData, Archives, device support, simulator caches, logs) and return the deletable items."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Scan Xcode Caches")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let (_, itemsByCategory) = await XcodeCleanService.shared.scanAllCategories()
        let total = itemsByCategory.values.flatMap { $0 }.reduce(Int64(0)) { $0 + $1.size }
        if itemsByCategory.isEmpty || total == 0 {
            return "No Xcode caches were found."
        }
        var lines: [String] = [
            "Xcode caches (total \(DiskManagerToolSupport.formatBytes(total))):",
        ]
        for category in XcodeCleanCategory.allCases {
            guard let items = itemsByCategory[category], !items.isEmpty else { continue }
            let categoryTotal = items.reduce(Int64(0)) { $0 + $1.size }
            lines.append("")
            lines.append("### \(category.displayName) — \(DiskManagerToolSupport.formatBytes(categoryTotal))")
            for item in items.prefix(50) {
                lines.append("- \(DiskManagerToolSupport.formatBytes(item.size)) · `\(item.path.path)` · modified \(DiskManagerToolSupport.formatDate(item.modificationDate))")
            }
            if items.count > 50 {
                lines.append("… and \(items.count - 50) more")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct CleanXcodeCachesTool: SuperAgentTool {
    let name = "disk-manager.clean-xcode-caches"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Delete the given Xcode cache paths and report the space freed. Pass paths returned by scan-xcode-caches."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "paths": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": PluginDiskManagerLocalization.string(
                        "Xcode cache paths to delete (from scan-xcode-caches)."
                    ),
                ],
            ],
            "required": ["paths"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = DiskManagerToolSupport.stringArray(arguments, "paths")?.count ?? 0
        return PluginDiskManagerLocalization.string("Delete \(count) Xcode cache path(s)")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let paths = DiskManagerToolSupport.stringArray(arguments, "paths")?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) else {
            return "Missing or invalid 'paths'. Provide an array of Xcode cache paths."
        }
        guard !paths.isEmpty else { return "No Xcode cache paths were provided." }

        // Rebuild XcodeCleanItem shells so the service can delete them. The
        // category is unknown at delete time, but the service only uses `path`.
        var items: [XcodeCleanItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let size = await DiskManagerToolSupport.sizeOfPath(path)
            items.append(XcodeCleanItem(
                name: url.lastPathComponent,
                path: url,
                size: size,
                category: .derivedData,
                modificationDate: Date()
            ))
        }

        do {
            try await XcodeCleanService.shared.delete(items: items)
            let freed = items.reduce(Int64(0)) { $0 + $1.size }
            let perLine = paths.map { "- `\($0)`" }
            return ([
                "Cleaned \(paths.count) Xcode cache path(s); freed ~\(DiskManagerToolSupport.formatBytes(freed)).",
            ] + perLine).joined(separator: "\n")
        } catch {
            return "Failed to clean Xcode caches: \(error.localizedDescription)"
        }
    }
}

// MARK: - Project Dependencies

struct ScanProjectsTool: SuperAgentTool {
    let name = "disk-manager.scan-projects"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Scan common development directories (~/Code, ~/Projects, …) for projects with cleanable build dependencies (node_modules, target, .build, venv)."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PluginDiskManagerLocalization.string("Scan Project Dependencies")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projects = await ProjectCleanerService.shared.scanProjects()
        guard !projects.isEmpty else {
            return "No projects with cleanable dependencies were found."
        }
        let total = projects.reduce(Int64(0)) { $0 + $1.totalSize }
        var lines: [String] = [
            "Projects with cleanable dependencies (total \(DiskManagerToolSupport.formatBytes(total))):",
        ]
        for project in projects.prefix(100) {
            lines.append("")
            lines.append("### \(project.name) — \(project.type.displayName) — \(DiskManagerToolSupport.formatBytes(project.totalSize))")
            lines.append("`\(project.path)`")
            for item in project.cleanableItems {
                lines.append("- \(DiskManagerToolSupport.formatBytes(item.size)) · `\(item.path)`")
            }
        }
        return lines.joined(separator: "\n")
    }
}

struct CleanProjectsTool: SuperAgentTool {
    let name = "disk-manager.clean-projects"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Delete the given project dependency paths (node_modules, target, .build, venv) and report the space freed. Pass paths returned by scan-projects."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "paths": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": PluginDiskManagerLocalization.string(
                        "Project dependency paths to delete (from scan-projects)."
                    ),
                ],
            ],
            "required": ["paths"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = DiskManagerToolSupport.stringArray(arguments, "paths")?.count ?? 0
        return PluginDiskManagerLocalization.string("Delete \(count) project dependency path(s)")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let paths = DiskManagerToolSupport.stringArray(arguments, "paths")?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) else {
            return "Missing or invalid 'paths'. Provide an array of project dependency paths."
        }
        guard !paths.isEmpty else { return "No project dependency paths were provided." }

        var items: [CleanableItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let size = await DiskManagerToolSupport.sizeOfPath(path)
            items.append(CleanableItem(path: path, name: url.lastPathComponent, size: size))
        }

        do {
            try await ProjectCleanerService.shared.cleanProjects(items)
            let freed = items.reduce(Int64(0)) { $0 + $1.size }
            let perLine = paths.map { "- `\($0)`" }
            return ([
                "Cleaned \(paths.count) project dependency path(s); freed ~\(DiskManagerToolSupport.formatBytes(freed)).",
            ] + perLine).joined(separator: "\n")
        } catch {
            return "Failed to clean project dependencies: \(error.localizedDescription)"
        }
    }
}

// MARK: - Generic Delete

struct DeleteFilesTool: SuperAgentTool {
    let name = "disk-manager.delete-files"

    func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string(
            "Delete arbitrary files or directories by absolute path. Use this as the generic cleanup tool; prefer the domain-specific scan/clean pairs when possible."
        )
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "paths": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": PluginDiskManagerLocalization.string(
                        "Absolute paths of files or directories to delete."
                    ),
                ],
            ],
            "required": ["paths"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = DiskManagerToolSupport.stringArray(arguments, "paths")?.count ?? 0
        return PluginDiskManagerLocalization.string("Delete \(count) file(s)")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let paths = DiskManagerToolSupport.stringArray(arguments, "paths")?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) else {
            return "Missing or invalid 'paths'. Provide an array of absolute paths."
        }
        guard !paths.isEmpty else { return "No paths were provided." }

        var deleted: [String] = []
        var failed: [(String, String)] = []
        for path in paths {
            do {
                try await DiskService.shared.deleteFile(at: URL(fileURLWithPath: path))
                deleted.append(path)
            } catch {
                failed.append((path, error.localizedDescription))
            }
        }

        var lines: [String] = ["Deleted \(deleted.count) of \(paths.count) path(s)."]
        if !deleted.isEmpty {
            lines.append("")
            lines.append("Deleted:")
            lines.append(contentsOf: deleted.map { "- `\($0)`" })
        }
        if !failed.isEmpty {
            lines.append("")
            lines.append("Failed:")
            lines.append(contentsOf: failed.map { "- `\($0)`: \($1)" })
        }
        return lines.joined(separator: "\n")
    }
}
