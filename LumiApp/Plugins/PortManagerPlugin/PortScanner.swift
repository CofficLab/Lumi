import Foundation
import SwiftUI
import MagicKit
import ShellKit

struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let command: String
    let pid: String
    let user: String
    let protocolName: String
    let port: String
    let address: String
}

final class PortScanner: Sendable, SuperLog {
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose: Bool = false
    static let shared = PortScanner()

    private init() {}

    func scanPorts() async -> [PortInfo] {
        do {
            let result = try await Shell.execute(
                executable: "/usr/sbin/lsof",
                arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"],
                options: ShellOptions(throwsOnError: false)
            )
            guard result.exitCode == 0 else { return [] }
            return parseLsofOutput(result.stdout)
        } catch {
            if Self.verbose {
                if PortManagerPlugin.verbose {
                                    PortManagerPlugin.logger.error("Failed to scan ports: \(error.localizedDescription)")
                }
            }
            return []
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
        do {
            _ = try await Shell.execute(executable: "/bin/kill", arguments: ["-9", pid])
        } catch {
            if Self.verbose {
                if PortManagerPlugin.verbose {
                                    PortManagerPlugin.logger.error("Failed to kill process \(pid): \(error.localizedDescription)")
                }
            }
            throw error
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
