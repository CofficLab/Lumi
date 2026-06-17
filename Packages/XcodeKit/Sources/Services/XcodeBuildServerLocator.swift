import Foundation

/// Resolves the `xcode-build-server` executable, preferring a bundled copy.
public enum XcodeBuildServerLocator {
    /// Set by the host app/plugin to point at a bundled tool (e.g. `Resources/Tools/xcode-build-server`).
    public nonisolated(unsafe) static var bundledToolPath: String?

    private static let fallbackPaths = [
        "/opt/homebrew/bin/xcode-build-server",
        "/usr/local/bin/xcode-build-server",
    ]

    public static func locate() async -> String? {
        await Task.detached(priority: .utility) {
            locateSync()
        }.value
    }

    public static func locateSync() -> String? {
        if let bundled = bundledToolPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bundled.isEmpty,
           FileManager.default.isExecutableFile(atPath: bundled) {
            return bundled
        }
        for path in fallbackPaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["xcode-build-server"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty,
              FileManager.default.isExecutableFile(atPath: path) else {
            return nil
        }
        return path
    }

    public static func detectedVersion(at executablePath: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public struct PreflightResult: Sendable, Equatable {
        public var xcodeBuildServerPath: String?
        public var xcodeBuildServerVersion: String?
        public var xcodeVersion: String?
        public var availableDiskBytes: Int64?
        public var issues: [String]

        public var isReady: Bool { issues.isEmpty && xcodeBuildServerPath != nil }
    }

    public static func runPreflight(minimumDiskBytes: Int64 = 5_368_709_120) -> PreflightResult {
        var issues: [String] = []
        let serverPath = locateSync()
        let serverVersion = serverPath.flatMap { detectedVersion(at: $0) }
        let xcodeVersion = ProjectInputFingerprint.currentToolchain().xcodeVersion

        if serverPath == nil {
            issues.append("xcode-build-server is not installed or not executable")
        }
        if xcodeVersion == nil {
            issues.append("Xcode command line tools are unavailable")
        }

        let diskBytes = availableDiskBytes()
        if let diskBytes, diskBytes < minimumDiskBytes {
            issues.append("Insufficient disk space for indexing (need at least 5 GB free)")
        }

        return PreflightResult(
            xcodeBuildServerPath: serverPath,
            xcodeBuildServerVersion: serverVersion,
            xcodeVersion: xcodeVersion,
            availableDiskBytes: diskBytes,
            issues: issues
        )
    }

    private static func availableDiskBytes() -> Int64? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return capacity
    }
}
