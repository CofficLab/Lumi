import Foundation

/// 远端脚本输出的纯函数解析器。
///
/// 不依赖网络与运行时环境，可用固定文本离线测试。
/// 所有字段都容错：远端缺少命令或输出格式异常时返回 nil / 跳过该行，
/// 不抛错、不崩溃。
public enum ServerMetricsParser {
    /// 解析 `RemoteScripts.metrics` 的分段输出。
    public static func parseMetrics(_ output: String) -> ServerMetrics {
        let sections = splitSections(output)
        var metrics = ServerMetrics()
        metrics.os = firstLine(sections["OS"])
        metrics.hostname = firstLine(sections["HOST"])
        metrics.uptime = firstLine(sections["UPTIME"])

        if let load = firstLine(sections["LOAD"]) {
            // Linux: "0.52 0.58 0.59 1/234 5678"；macOS: "{ 1.23 1.45 1.67 }"
            let cleaned = load.replacingOccurrences(of: "{", with: "")
                .replacingOccurrences(of: "}", with: "")
            let values = cleaned.split(separator: " ").compactMap { Double($0) }
            if values.count >= 3 {
                metrics.load1 = values[0]
                metrics.load5 = values[1]
                metrics.load15 = values[2]
            }
        }
        if let cores = firstLine(sections["CORES"]) {
            metrics.cores = Int(cores.trimmingCharacters(in: .whitespaces))
        }
        if let mem = firstLine(sections["MEM"]) {
            // free -b awk 输出: total available
            let values = mem.split(separator: " ").compactMap { Int64($0) }
            if values.count >= 2, values[0] > 0 {
                metrics.memTotalBytes = values[0]
                metrics.memUsedBytes = max(0, values[0] - values[1])
            }
        }
        if let disk = firstLine(sections["DISK"]) {
            // df -P -k: filesystem 1024-blocks used available capacity mount
            let fields = disk.split(separator: " ").map(String.init)
            if fields.count >= 3,
               let total = Int64(fields[1]), let used = Int64(fields[2]) {
                metrics.diskTotalBytes = total * 1024
                metrics.diskUsedBytes = used * 1024
            }
        }
        metrics.cpuPercent = parseCPU(sections["CPU"] ?? [])
        return metrics
    }

    /// 解析 ps 输出（首行表头跳过），最多保留 20 条。
    public static func parseProcesses(_ output: String) -> [ServerProcess] {
        var result: [ServerProcess] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.uppercased().hasPrefix("PID") { continue }
            // command 可能含空格，只切前 4 刀。
            let fields = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard fields.count >= 5,
                  let pid = Int(fields[0]),
                  let cpu = Double(fields[2].replacingOccurrences(of: ",", with: ".")),
                  let mem = Double(fields[3].replacingOccurrences(of: ",", with: "."))
            else { continue }
            result.append(ServerProcess(
                pid: pid,
                user: String(fields[1]),
                cpu: cpu,
                mem: mem,
                command: String(fields[4])
            ))
            if result.count >= 20 { break }
        }
        return result
    }

    /// 解析 docker ps 的制表符分隔输出。
    public static func parseContainers(_ output: String) -> [ServerContainer] {
        var result: [ServerContainer] = []
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 4, !fields[0].isEmpty else { continue }
            result.append(ServerContainer(
                name: fields[0],
                image: fields[1],
                state: ServerContainer.State(rawValue: fields[2]) ?? .unknown,
                status: fields[3]
            ))
        }
        return result
    }

    // MARK: - Private

    /// 按 `===NAME===` 标记把输出切成段。
    private static func splitSections(_ output: String) -> [String: [String]] {
        var sections: [String: [String]] = [:]
        var current: String?
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("==="), trimmed.hasSuffix("==="), trimmed.count > 6 {
                current = String(trimmed.dropFirst(3).dropLast(3))
                sections[current ?? ""] = []
            } else if let current {
                sections[current, default: []].append(String(line))
            }
        }
        return sections
    }

    private static func firstLine(_ lines: [String]?) -> String? {
        lines?.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?
            .trimmingCharacters(in: .whitespaces)
    }

    /// 用 /proc/stat 两次采样差值计算 CPU 使用率。
    private static func parseCPU(_ lines: [String]) -> Double? {
        let samples = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("cpu ") }
            .compactMap { line -> (total: Double, idle: Double)? in
                let values = line.split(separator: " ").dropFirst().compactMap { Double($0) }
                guard values.count >= 5 else { return nil }
                // user nice system idle iowait irq softirq steal ...
                return (values.reduce(0, +), values[3] + values[4])
            }
        guard samples.count >= 2 else { return nil }
        let totalDelta = samples[1].total - samples[0].total
        guard totalDelta > 0 else { return nil }
        let busyDelta = totalDelta - (samples[1].idle - samples[0].idle)
        return min(100, max(0, busyDelta / totalDelta * 100))
    }
}