import Foundation
import LumiLoggingKit
import SwiftUI
import LumiUI
import KitShell
import os

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
    case outputTruncated

    public var errorDescription: String? {
        switch self {
        case .scanFailed(let message):
            return message
        case .outputTruncated:
            return "lsof output was truncated and is incomplete."
        }
    }
}

public final class PortScanner: Sendable, SuperLog {
    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.port-manager", category: "PortScanner")
    public static let shared = PortScanner()

    /// lsof 监听列表可能很大；放宽捕获上限，避免正常结果被默认 64KiB 截断（#258）。
    static let maxOutputBytes = 16 * 1024 * 1024

    private init() {}

    public func scanPorts() async throws -> [PortInfo] {
        do {
            let result = try await Shell.execute(
                executable: "/usr/sbin/lsof",
                arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"],
                options: ShellOptions(throwsOnError: false, maxOutputBytes: Self.maxOutputBytes)
            )
            return try interpretScanResult(result)
        } catch {
            if Self.verbose {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to scan ports: \(error.localizedDescription)")
                }
            }
            throw error
        }
    }

    /// 把 lsof 退出码 + stderr 分类为「成功/无匹配」或「扫描失败」。
    /// lsof 无匹配时退出码为 1 且 stderr 为空，是合法的「无监听端口」结果；
    /// 信号终止（KitShell 以 terminationStatus 上报，如 SIGTERM=15）或其他非零
    /// 退出必须抛 scanFailed，不能伪装成无端口（#523）。
    static func ensureScanSucceeded(exitCode: Int32, stderr: String) throws {
        guard exitCode != 0 else { return }
        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if exitCode == 1 && message.isEmpty { return }
        throw PortScannerError.scanFailed(
            message.isEmpty ? "lsof 扫描异常退出（退出码 \(exitCode)）" : message
        )
    }

    /// 把 lsof 结果解释为监听列表：退出码异常或输出被截断都必须抛错，
    /// 不能把 KitShell 保留的尾部当成完整列表而静默丢端口（#258）。
    func interpretScanResult(_ result: ShellResult) throws -> [PortInfo] {
        try Self.ensureScanSucceeded(exitCode: result.exitCode, stderr: result.stderr)
        if result.stdoutTruncated {
            throw PortScannerError.outputTruncated
        }
        return parseLsofOutput(result.stdout)
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
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to kill process \(pid): \(error.localizedDescription)")
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
