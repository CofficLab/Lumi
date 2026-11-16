import Foundation

/// 一次探测得到的结构化指标。字段可缺省：远端缺少对应命令时为 nil。
public struct ServerMetrics: Equatable, Sendable {
    public var os: String?
    public var hostname: String?
    public var uptime: String?
    public var load1: Double?
    public var load5: Double?
    public var load15: Double?
    public var cores: Int?
    /// 0–100；由 /proc/stat 两次采样差值计算，缺省时为 nil。
    public var cpuPercent: Double?
    public var memTotalBytes: Int64?
    public var memUsedBytes: Int64?
    public var diskTotalBytes: Int64?
    public var diskUsedBytes: Int64?

    public init() {}

    public var memPercent: Double? {
        guard let total = memTotalBytes, total > 0, let used = memUsedBytes else { return nil }
        return Double(used) / Double(total) * 100
    }

    public var diskPercent: Double? {
        guard let total = diskTotalBytes, total > 0, let used = diskUsedBytes else { return nil }
        return Double(used) / Double(total) * 100
    }
}

/// 进程条目（ps 输出解析结果）。
public struct ServerProcess: Equatable, Identifiable, Sendable {
    public let pid: Int
    public let user: String
    public let cpu: Double
    public let mem: Double
    public let command: String

    public var id: Int { pid }

    public init(pid: Int, user: String, cpu: Double, mem: Double, command: String) {
        self.pid = pid
        self.user = user
        self.cpu = cpu
        self.mem = mem
        self.command = command
    }
}

/// Docker 容器条目。
public struct ServerContainer: Equatable, Identifiable, Sendable {
    public enum State: String, Sendable {
        case running, exited, paused, created, restarting, removing, dead, unknown
    }

    public let name: String
    public let image: String
    public let state: State
    public let status: String

    public var id: String { name }

    public init(name: String, image: String, state: State, status: String) {
        self.name = name
        self.image = image
        self.state = state
        self.status = status
    }

    /// docker 容器名合法字符集；用于在执行动作前校验，杜绝命令拼接注入。
    public static func isValidName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 128 else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-" }
    }
}