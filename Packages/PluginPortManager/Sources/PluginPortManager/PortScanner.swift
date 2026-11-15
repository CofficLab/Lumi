import Foundation
import LumiLoggingKit
import SwiftUI
import LumiUI
import KitShell
import os

public struct PortInfo: Identifiable, Hashable, Sendable, SuperLog {
    public let id = UUID()
    public let command: String
    public let pid: String
    public let user: String
    public let protocolName: String
    public let port: String
    public let address: String
    /// 扫描时的进程启动时间（ps lstart）。kill 前用它复核进程身份，
    /// 防止 PID 被复用后误杀无关进程（#246）。
    public var processStartTime: String? = nil
}

public enum PortScannerError: LocalizedError, Sendable {
    case scanFailed(String)
    case outputTruncated
    case killTargetIdentityChanged
    case killTargetExited
    case killTargetSocketChanged
    case killIdentityUnavailable

    public var errorDescription: String? {
        switch self {
        case .scanFailed(let message):
            return message
        case .outputTruncated:
            return "lsof output was truncated and is incomplete."
        case .killTargetIdentityChanged:
            return "The PID now belongs to a different process (the original process exited and the PID was reused). The kill was refused."
        case .killTargetExited:
            return "The process has already exited. The kill was refused."
        case .killTargetSocketChanged:
            return "The process no longer listens on the selected port. The kill was refused."
        case .killIdentityUnavailable:
            return "The process identity could not be verified. The kill was refused."
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
            let ports = try interpretScanResult(result)
            return await Self.attachProcessStartTimes(to: ports)
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

    /// 扫描时批量记录各 PID 的启动时间，作为 kill 前的身份基线（#246）。
    /// ps 失败时基线为 nil，kill 会因无法验证身份而拒绝（fail-closed）。
    static func attachProcessStartTimes(to ports: [PortInfo]) async -> [PortInfo] {
        let pids = Array(Set(ports.map(\.pid))).sorted()
        guard !pids.isEmpty else { return ports }

        var startTimes: [String: String] = [:]
        if let result = try? await Shell.execute(
            executable: "/bin/ps",
            arguments: ["-o", "pid=,lstart=", "-p", pids.joined(separator: ",")],
            options: ShellOptions(throwsOnError: false, maxOutputBytes: maxOutputBytes)
        ), result.exitCode == 0 {
            startTimes = parseProcessStartTimes(result.stdout)
        }

        return ports.map { port in
            var updated = port
            updated.processStartTime = startTimes[port.pid]
            return updated
        }
    }

    /// 解析 `ps -o pid=,lstart=` 输出：首列 PID，其余为启动时间。
    static func parseProcessStartTimes(_ output: String) -> [String: String] {
        var startTimes: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, Int(parts[0]) != nil else { continue }
            startTimes[String(parts[0])] = parts[1...].joined(separator: " ")
        }
        return startTimes
    }

    /// kill 前的身份与端口归属复核（#246）：启动时间必须与扫描时一致，
    /// 且该进程仍在监听目标端口；任何一项无法确认都拒绝执行。
    static func ensureKillTargetStillValid(
        expectedStartTime: String?,
        currentStartTime: String?,
        expectedPort: String,
        currentListeningPorts: [PortInfo]
    ) throws {
        guard let expectedStartTime else {
            throw PortScannerError.killIdentityUnavailable
        }
        guard let currentStartTime else {
            throw PortScannerError.killTargetExited
        }
        guard currentStartTime == expectedStartTime else {
            throw PortScannerError.killTargetIdentityChanged
        }
        guard currentListeningPorts.contains(where: { $0.port == expectedPort }) else {
            throw PortScannerError.killTargetSocketChanged
        }
    }

    public func killProcess(_ port: PortInfo) async throws {
        try await verifyKillTarget(port)
        do {
            _ = try await Shell.execute(executable: "/bin/kill", arguments: ["-9", port.pid])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)Failed to kill process \(port.pid): \(error.localizedDescription)")
            }
            throw error
        }
    }

    func verifyKillTarget(_ port: PortInfo) async throws {
        let psResult = try await Shell.execute(
            executable: "/bin/ps",
            arguments: ["-o", "pid=,lstart=", "-p", port.pid],
            options: ShellOptions(throwsOnError: false, maxOutputBytes: Self.maxOutputBytes)
        )
        let currentStartTime = Self.parseProcessStartTimes(psResult.stdout)[port.pid]

        let lsofResult = try await Shell.execute(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-p", port.pid, "-iTCP", "-sTCP:LISTEN", "-n", "-P"],
            options: ShellOptions(throwsOnError: false, maxOutputBytes: Self.maxOutputBytes)
        )
        let currentListeningPorts = try interpretScanResult(lsofResult)

        try Self.ensureKillTargetStillValid(
            expectedStartTime: port.processStartTime,
            currentStartTime: currentStartTime,
            expectedPort: port.port,
            currentListeningPorts: currentListeningPorts
        )
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
