import CryptoKit
import Foundation

/// Computes content fingerprints for Xcode project inputs that affect semantic indexing.
public enum ProjectInputFingerprint {
    public static func compute(
        workspaceURL: URL,
        schemeName: String?
    ) async -> IndexManifest.InputFingerprints {
        await Task.detached(priority: .utility) {
            computeSync(workspaceURL: workspaceURL, schemeName: schemeName)
        }.value
    }

    public static func computeSync(
        workspaceURL: URL,
        schemeName: String?
    ) -> IndexManifest.InputFingerprints {
        IndexManifest.InputFingerprints(
            pbxprojHash: hashPBXProjFiles(near: workspaceURL),
            packageResolvedHash: hashPackageResolved(near: workspaceURL),
            xcschemeHash: hashSchemeFiles(workspaceURL: workspaceURL, schemeName: schemeName)
        )
    }

    public static func currentToolchain(
        xcodeBuildServerVersion: String? = nil
    ) -> IndexManifest.ToolchainInfo {
        IndexManifest.ToolchainInfo(
            xcodeVersion: xcodeVersionString(),
            xcodeBuildServerVersion: xcodeBuildServerVersion
        )
    }

    private static func xcodeVersionString() -> String? {
        let output = runCommand(executable: "/usr/bin/xcodebuild", arguments: ["-version"])
        guard let firstLine = output?.split(separator: "\n").first else { return nil }
        let text = String(firstLine)
        if let range = text.range(of: "Xcode ") {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hashPBXProjFiles(near workspaceURL: URL) -> String? {
        let projectRoots = projectRoots(for: workspaceURL)
        var paths: [URL] = []
        for root in projectRoots {
            if root.pathExtension == "xcodeproj" {
                let pbx = root.appendingPathComponent("project.pbxproj")
                if FileManager.default.fileExists(atPath: pbx.path) {
                    paths.append(pbx)
                }
            }
        }
        return hashFiles(paths.sorted { $0.path < $1.path })
    }

    private static func hashPackageResolved(near workspaceURL: URL) -> String? {
        let roots = projectRoots(for: workspaceURL)
        var paths: [URL] = []
        for root in roots {
            let resolved = root.deletingLastPathComponent()
                .appendingPathComponent("Package.resolved")
            if FileManager.default.fileExists(atPath: resolved.path) {
                paths.append(resolved)
            }
            if root.pathExtension == "xcodeproj" {
                let workspaceResolved = root.appendingPathComponent("project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
                if FileManager.default.fileExists(atPath: workspaceResolved.path) {
                    paths.append(workspaceResolved)
                }
            }
        }
        return hashFiles(paths.sorted { $0.path < $1.path })
    }

    private static func hashSchemeFiles(workspaceURL: URL, schemeName: String?) -> String? {
        guard let schemeName, !schemeName.isEmpty else { return nil }
        var paths: [URL] = []
        for root in projectRoots(for: workspaceURL) {
            let shared = root.appendingPathComponent("xcshareddata/xcschemes/\(schemeName).xcscheme")
            let user = root.appendingPathComponent("xcuserdata").appendingPathComponent("xcschemes/\(schemeName).xcscheme")
            if FileManager.default.fileExists(atPath: shared.path) {
                paths.append(shared)
            } else if FileManager.default.fileExists(atPath: user.path) {
                paths.append(user)
            }
        }
        return hashFiles(paths)
    }

    private static func projectRoots(for workspaceURL: URL) -> [URL] {
        switch workspaceURL.pathExtension {
        case "xcodeproj":
            return [workspaceURL]
        case "xcworkspace":
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: workspaceURL,
                includingPropertiesForKeys: nil
            ) else {
                return [workspaceURL]
            }
            let projects = contents.filter { $0.pathExtension == "xcodeproj" }
            return projects.isEmpty ? [workspaceURL] : projects
        default:
            return [workspaceURL]
        }
    }

    private static func hashFiles(_ urls: [URL]) -> String? {
        guard !urls.isEmpty else { return nil }
        var hasher = SHA256()
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            hasher.update(data: Data(url.path.utf8))
            hasher.update(data: data)
        }
        let digest = hasher.finalize()
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func runCommand(executable: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
