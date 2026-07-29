import Foundation
import SuperLogKit
import SwiftUI
import LumiUI
import ShellKit

public struct PortInfo: Identifiable, Hashable, SuperLog {
    public let id = UUID()
    public let command: String
    public let pid: String
    public let user: String
    public let protocolName: String
    public let port: String
    public let address: String
}

public enum PortScannerError: LocalizedError, Sendable {
    case scanFailed(String)

    public var errorDescription: String? {
        switch self {
        case .scanFailed(let message):
            return message
        }
    }
}

public final class PortScanner: Sendable, SuperLog {
    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = false
    public static let shared = PortScanner()

    private init() {}

    public func scanPorts() async throws -> [PortInfo] {
        do {
            let result = try await Shell.execute(
                executable: "/usr/sbin/lsof",
                arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"],
                options: ShellOptions(throwsOnError: false)
            )
            guard result.exitCode == 0 else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                if message.isEmpty {
                    return []
                }
                throw PortScannerError.scanFailed(message)
            }
            return parseLsofOutput(result.stdout)
        } catch {
            if Self.verbose {
                if PortManagerPlugin.verbose {
                    PortManagerPlugin.logger.error("\(Self.t)Failed to scan ports: \(error.localizedDescription)")
                }
            }
            throw error
        }
    }

    func parseLsofOutput(_ output: String) -> [PortInfo] {
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

                if let address = Self.listeningAddress(in: parts[(protoIndex + 1)...]) {
                    // Check if we already have this port (sometimes lsof lists IPv4 and IPv6 separately for same port)
                    // We might want to keep both or dedup. Let's keep all for now.
                    ports.append(PortInfo(command: command, pid: pid, user: user, protocolName: proto, port: address.port, address: address.raw))
                }
            }
        }
        return ports
    }

    private static func listeningAddress(in parts: ArraySlice<String>) -> (raw: String, port: String)? {
        for part in parts {
            let address = part.trimmingCharacters(in: CharacterSet(charactersIn: ","))
            guard let port = port(from: address) else { continue }
            return (address, port)
        }
        return nil
    }

    private static func port(from address: String) -> String? {
        if address.hasPrefix("[") {
            guard let closeBracket = address.lastIndex(of: "]") else { return nil }
            let separatorIndex = address.index(after: closeBracket)
            guard separatorIndex < address.endIndex, address[separatorIndex] == ":" else { return nil }
            let portStart = address.index(after: separatorIndex)
            guard portStart < address.endIndex else { return nil }
            let port = String(address[portStart...])
            return Int(port) == nil ? nil : port
        }

        guard let separatorIndex = address.lastIndex(of: ":") else { return nil }
        let portStart = address.index(after: separatorIndex)
        guard portStart < address.endIndex else { return nil }
        let port = String(address[portStart...])
        return Int(port) == nil ? nil : port
    }

    public func killProcess(pid: String) async throws {
        do {
            _ = try await Shell.execute(executable: "/bin/kill", arguments: ["-9", pid])
        } catch {
            if Self.verbose {
                if PortManagerPlugin.verbose {
                    PortManagerPlugin.logger.error("\(Self.t)Failed to kill process \(pid): \(error.localizedDescription)")
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
