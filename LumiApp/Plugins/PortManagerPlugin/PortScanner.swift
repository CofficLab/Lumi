import Foundation
import SwiftUI
import OSLog

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let command: String
    let pid: String
    let user: String
    let protocolName: String
    let port: String
    let address: String
}

final class PortScanner: Sendable {
    static let shared = PortScanner()
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "PortScanner")

    func scanPorts() async -> [PortInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/usr/sbin/lsof"
                // -iTCP: list TCP files
                // -sTCP:LISTEN: list only listening ports
                // -n: no host names
                // -P: no port names
                task.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]

                let pipe = Pipe()
                task.standardOutput = pipe

                do {
                    try task.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        let ports = self.parseLsofOutput(output)
                        continuation.resume(returning: ports)
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    os_log(.error, "Failed to scan ports: %s", error.localizedDescription)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func parseLsofOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)

        // Skip header line
        for line in lines.dropFirst() {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            // Expected format: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME (STATE)
            // Minimum parts should be around 9
            if parts.count >= 8 {
                let command = parts[0]
                let pid = parts[1]
                let user = parts[2]

                // Find protocol (TCP)
                guard let protoIndex = parts.firstIndex(where: { $0 == "TCP" || $0 == "UDP" }) else { continue }
                let proto = parts[protoIndex]

                // Address is usually after "TCP" (skipping DEVICE, SIZE/OFF, NODE)
                // But lsof output is fixed width-ish but separated by spaces.
                // Let's look for the part that contains ":" and starts with a digit or "*" or "[" (IPv6)

                if let addressPart = parts.first(where: { $0.contains(":") && ($0.first?.isNumber == true || $0.first == "*" || $0.first == "[") }) {
                    let subParts = addressPart.components(separatedBy: ":")
                    if let last = subParts.last, let _ = Int(last) {
                        let port = last

                        // Check if we already have this port (sometimes lsof lists IPv4 and IPv6 separately for same port)
                        // We might want to keep both or dedup. Let's keep all for now.
                        ports.append(PortInfo(command: command, pid: pid, user: user, protocolName: proto, port: port, address: addressPart))
                    }
                }
            }
        }
        return ports
    }

    func killProcess(pid: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.launchPath = "/bin/kill"
                task.arguments = ["-9", pid]

                do {
                    try task.run()
                    continuation.resume(returning: ())
                } catch {
                    os_log(.error, "Failed to kill process %s: %s", pid, error.localizedDescription)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(PortManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
