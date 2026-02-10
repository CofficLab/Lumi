import Foundation
import OSLog
import AppKit
import MagicKit

@MainActor
class HostsFileService: SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    static let shared = HostsFileService()
    private let hostsPath = "/etc/hosts"

    private init() {
        if Self.verbose {
            os_log("\(self.t)Hosts file service initialized")
        }
    }

    func readHosts() async throws -> String {
        if Self.verbose {
            os_log("\(self.t)Reading hosts file")
        }
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    func saveHosts(content: String) async throws {
        if Self.verbose {
            os_log("\(self.t)Saving hosts file")
        }

        // Create a temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("hosts_tmp_\(UUID().uuidString)")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        // Use osascript to move the temp file to /etc/hosts with admin privileges
        let script = """
        do shell script "cp '\(tempURL.path)' '\(hostsPath)' && chmod 644 '\(hostsPath)' && rm '\(tempURL.path)'" with administrator privileges
        """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                    if let error = error {
                        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                        os_log(.error, "\(Self.t)Failed to execute AppleScript: \(message)")
                        continuation.resume(throwing: NSError(domain: "HostsFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                    } else {
                        continuation.resume(returning: ())
                    }
                } else {
                    os_log(.error, "\(Self.t)Failed to create NSAppleScript")
                    continuation.resume(throwing: NSError(domain: "HostsFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create NSAppleScript"]))
                }
            }
        }
    }

    func backupHosts(to url: URL) throws {
        if Self.verbose {
            os_log("\(self.t)Backing up hosts file to: \(url.path)")
        }
        let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func importHosts(from url: URL) async throws {
        if Self.verbose {
            os_log("\(self.t)Importing hosts from file: \(url.path)")
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        try await saveHosts(content: content)
    }
}
