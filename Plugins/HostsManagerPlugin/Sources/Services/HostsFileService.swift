import Foundation
import SuperLogKit
import AppKit

@MainActor
public class HostsFileService: SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = true
    public static let shared = HostsFileService()
    private let hostsPath = "/etc/hosts"

    private init() {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Hosts file service initialized")
            }
        }
    }

    public func readHosts() async throws -> String {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Reading hosts file")
            }
        }
        return try Self.readTextFile(at: URL(fileURLWithPath: hostsPath))
    }

    public func saveHosts(content: String) async throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Saving hosts file")
            }
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
                        if HostsManagerPlugin.verbose {
                                                    HostsManagerPlugin.logger.error("\(Self.t)Failed to execute AppleScript: \(message)")
                        }
                        continuation.resume(throwing: NSError(domain: "HostsFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                    } else {
                        continuation.resume(returning: ())
                    }
                } else {
                    if HostsManagerPlugin.verbose {
                                            HostsManagerPlugin.logger.error("\(Self.t)Failed to create NSAppleScript")
                    }
                    continuation.resume(throwing: NSError(domain: "HostsFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create NSAppleScript"]))
                }
            }
        }
    }

    public func backupHosts(to url: URL) throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Backing up hosts file to: \(url.path)")
            }
        }
        let content = try Self.readTextFile(at: URL(fileURLWithPath: hostsPath))
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func importHosts(from url: URL) async throws {
        if Self.verbose {
            if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.info("\(self.t)Importing hosts from file: \(url.path)")
            }
        }
        let content = try Self.readTextFile(at: url)
        try await saveHosts(content: content)
    }

    nonisolated static func readTextFile(at url: URL) throws -> String {
        var encoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &encoding)
    }
}
