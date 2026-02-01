import Foundation
import OSLog
import AppKit

class HostsFileService {
    static let shared = HostsFileService()
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "HostsFileService")
    private let hostsPath = "/etc/hosts"
    
    func readHosts() async throws -> String {
        return try String(contentsOfFile: hostsPath, encoding: .utf8)
    }
    
    func saveHosts(content: String) async throws {
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
                        continuation.resume(throwing: NSError(domain: "HostsFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                    } else {
                        continuation.resume(returning: ())
                    }
                } else {
                    continuation.resume(throwing: NSError(domain: "HostsFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create NSAppleScript"]))
                }
            }
        }
    }
    
    func backupHosts(to url: URL) throws {
        let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func importHosts(from url: URL) async throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        try await saveHosts(content: content)
    }
}
