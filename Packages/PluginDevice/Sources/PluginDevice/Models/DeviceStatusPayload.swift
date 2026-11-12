import Foundation

/// 设备状态卡片的查询范围。
///
/// 范围决定卡片画哪些区块，也决定工具采集哪些指标。
/// 分档的意义在于「一次查询只回答一个问题」：问内存就别把 GPU 温度也糊上来。
public enum DeviceStatusScope: String, Codable, Sendable, CaseIterable {
    /// 总览：CPU / 内存 / GPU / 电池 / 磁盘一屏看完。
    case overview
    /// CPU 明细：总占用、每核分布、load average、user/system/idle 拆分。
    case cpu
    /// 内存明细：已用 / 总量 / 内存压力等级。
    case memory
    /// 存储明细：系统盘与外接卷容量。
    case storage
    /// 温度明细：各传感器读数与峰值。
    case thermal
    /// 进程排行：CPU 榜与内存榜。
    case processes

    /// 范围的中文名，用于错误提示与日志。
    public var displayName: String {
        switch self {
        case .overview: return "总览"
        case .cpu: return "CPU"
        case .memory: return "内存"
        case .storage: return "存储"
        case .thermal: return "温度"
        case .processes: return "进程"
        }
    }

    /// 是否需要采集进程列表。
    ///
    /// 进程采样最贵（要遍历 `/proc` 并读每个进程的时间片），
    /// 因此只有明确问进程时才采。
    public var needsProcesses: Bool { self == .processes }
}

/// 设备身份信息。
///
/// 这部分几乎不随时间变化，但每次查询都带上——
/// 卡片要显示「这是哪台机器」，工具返回给 LLM 的文本也需要它做上下文。
public struct DeviceIdentity: Codable, Sendable, Equatable {
    /// 设备名。
    public let name: String
    /// macOS 版本，形如 `macOS 15.1.0`。
    public let osVersion: String
    /// 处理器型号。
    public let processorName: String
    /// 物理核心数。
    public let physicalCoreCount: Int
    /// 逻辑核心数。
    public let logicalCoreCount: Int
    /// 系统已运行时长（秒）。
    public let uptime: TimeInterval

    public init(
        name: String,
        osVersion: String,
        processorName: String,
        physicalCoreCount: Int,
        logicalCoreCount: Int,
        uptime: TimeInterval
    ) {
        self.name = name
        self.osVersion = osVersion
        self.processorName = processorName
        self.physicalCoreCount = physicalCoreCount
        self.logicalCoreCount = logicalCoreCount
        self.uptime = uptime
    }
}

/// CPU 状态快照。
public struct DeviceCPUStatus: Codable, Sendable, Equatable {
    /// 总占用百分比（0–100）。
    public let usagePercentage: Double
    /// 每核占用百分比（0–100）。
    public let perCoreUsage: [Double]
    /// 1 / 5 / 15 分钟负载均值。
    public let loadAverage: [Double]
    /// 用户态占比（0–100）。
    public let userPercentage: Double
    /// 内核态占比（0–100）。
    public let systemPercentage: Double
    /// 空闲占比（0–100）。
    public let idlePercentage: Double

    public init(
        usagePercentage: Double,
        perCoreUsage: [Double],
        loadAverage: [Double],
        userPercentage: Double,
        systemPercentage: Double,
        idlePercentage: Double
    ) {
        self.usagePercentage = usagePercentage
        self.perCoreUsage = perCoreUsage
        self.loadAverage = loadAverage
        self.userPercentage = userPercentage
        self.systemPercentage = systemPercentage
        self.idlePercentage = idlePercentage
    }
}

/// 内存状态快照。
public struct DeviceMemoryStatus: Codable, Sendable, Equatable {
    /// 占用百分比（0–100）。
    public let usagePercentage: Double
    /// 已用字节数。
    public let usedBytes: UInt64
    /// 总量字节数。
    public let totalBytes: UInt64
    /// 内存压力等级（系统原文，例如 `Normal`）。
    public let pressure: String

    public init(
        usagePercentage: Double,
        usedBytes: UInt64,
        totalBytes: UInt64,
        pressure: String
    ) {
        self.usagePercentage = usagePercentage
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
    }
}

/// GPU 状态快照。
public struct DeviceGPUStatus: Codable, Sendable, Equatable {
    /// 设备占用百分比（0–100）。
    public let utilizationPercentage: Double
    /// 已用显存字节数。
    public let usedMemoryBytes: UInt64
    /// 显存总量字节数。
    public let totalMemoryBytes: UInt64
    /// 温度（℃）；读不到时为 0。
    public let temperatureCelsius: Double
    /// GPU 型号。
    public let modelName: String

    public init(
        utilizationPercentage: Double,
        usedMemoryBytes: UInt64,
        totalMemoryBytes: UInt64,
        temperatureCelsius: Double,
        modelName: String
    ) {
        self.utilizationPercentage = utilizationPercentage
        self.usedMemoryBytes = usedMemoryBytes
        self.totalMemoryBytes = totalMemoryBytes
        self.temperatureCelsius = temperatureCelsius
        self.modelName = modelName
    }
}

/// 电池状态快照。
public struct DeviceBatteryStatus: Codable, Sendable, Equatable {
    /// 电量比例（0–1）。
    public let level: Double
    /// 是否正在充电。
    public let isCharging: Bool
    /// 是否已充满。
    public let isCharged: Bool
    /// 健康度百分比（0–100）。
    public let healthPercentage: Double
    /// 循环次数。
    public let cycleCount: Int
    /// 电池温度（℃）。
    public let temperatureCelsius: Double
    /// 当前功率（W）。
    public let watts: Double
    /// 本机是否带内置电池。
    ///
    /// 台式机为 `false`，此时卡片不应显示电池区块。
    public let hasBattery: Bool

    public init(
        level: Double,
        isCharging: Bool,
        isCharged: Bool,
        healthPercentage: Double,
        cycleCount: Int,
        temperatureCelsius: Double,
        watts: Double,
        hasBattery: Bool
    ) {
        self.level = level
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.healthPercentage = healthPercentage
        self.cycleCount = cycleCount
        self.temperatureCelsius = temperatureCelsius
        self.watts = watts
        self.hasBattery = hasBattery
    }
}

/// 单个磁盘卷的状态快照。
public struct DeviceVolumeStatus: Codable, Sendable, Equatable {
    /// 卷名。
    public let name: String
    /// 容量总字节数。
    public let totalBytes: Int64
    /// 剩余字节数。
    public let availableBytes: Int64
    /// 是否为系统内置卷。
    public let isInternal: Bool
    /// 是否可弹出。
    public let isEjectable: Bool

    public init(
        name: String,
        totalBytes: Int64,
        availableBytes: Int64,
        isInternal: Bool,
        isEjectable: Bool
    ) {
        self.name = name
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.isInternal = isInternal
        self.isEjectable = isEjectable
    }

    /// 已用字节数。
    public var usedBytes: Int64 {
        max(0, totalBytes - availableBytes)
    }

    /// 占用百分比（0–100）。
    public var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

/// 单个温度传感器读数。
public struct DeviceThermalReading: Codable, Sendable, Equatable {
    /// 传感器下标。
    public let index: Int
    /// 传感器类别原文（`die` / `device` / `surface`）；无法判定时为 `nil`。
    public let kind: String?
    /// 温度（℃）。
    public let celsius: Double

    public init(index: Int, kind: String?, celsius: Double) {
        self.index = index
        self.kind = kind
        self.celsius = celsius
    }
}

/// 温度状态快照。
public struct DeviceThermalStatus: Codable, Sendable, Equatable {
    /// 全部传感器读数。
    public let readings: [DeviceThermalReading]
    /// 最高温度（℃）；无读数时为 `nil`。
    public let peakCelsius: Double?

    public init(readings: [DeviceThermalReading], peakCelsius: Double?) {
        self.readings = readings
        self.peakCelsius = peakCelsius
    }
}

/// 单个进程的状态快照。
public struct DeviceProcessStatus: Codable, Sendable, Equatable {
    /// 进程 PID。
    public let pid: Int32
    /// 进程名。
    public let name: String
    /// CPU 占用百分比（0–100）。
    public let cpuPercentage: Double
    /// 内存占用字节数。
    public let memoryBytes: Int64
    /// 同名进程份数；聚合后大于 1 时卡片需标注。
    public let instanceCount: Int
    /// 是否为 Lumi 自身进程。
    public let isCurrentApp: Bool

    public init(
        pid: Int32,
        name: String,
        cpuPercentage: Double,
        memoryBytes: Int64,
        instanceCount: Int,
        isCurrentApp: Bool
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercentage = cpuPercentage
        self.memoryBytes = memoryBytes
        self.instanceCount = instanceCount
        self.isCurrentApp = isCurrentApp
    }
}

/// 设备状态卡片的结构化载荷。
///
/// ## 为什么载荷存在 `Message.content` 里
///
/// 与磁盘测速卡片同理：`MessageManaging.updateMessage(id:in:content:)`
/// **只能改 content**，改不了已落库的 `metadata`。若把载荷放在 metadata，
/// 卡片一旦插入就无法更新。因此载荷放 content，metadata 只留时间线标记。
///
/// 代价是 `content` 不再是人话，但消息正文的语义本来就是「给人看的摘要」，
/// 渲染器会优先解析结构化载荷、失败时回退到纯文本。
public struct DeviceStatusPayload: Codable, Sendable, Equatable {

    /// 本次查询的范围。
    public let scope: DeviceStatusScope
    /// 采集时间戳（秒）。
    public let timestamp: TimeInterval
    /// 设备身份。
    public let device: DeviceIdentity
    /// CPU 状态；范围不含 CPU 时为 `nil`。
    public let cpu: DeviceCPUStatus?
    /// 内存状态；范围不含内存时为 `nil`。
    public let memory: DeviceMemoryStatus?
    /// GPU 状态；范围不含 GPU 时为 `nil`。
    public let gpu: DeviceGPUStatus?
    /// 电池状态；范围不含电池时为 `nil`。
    public let battery: DeviceBatteryStatus?
    /// 磁盘卷列表；范围不含存储时为空数组。
    public let volumes: [DeviceVolumeStatus]
    /// 温度状态；范围不含温度时为 `nil`。
    public let thermal: DeviceThermalStatus?
    /// 进程列表；范围不含进程时为空数组。
    public let processes: [DeviceProcessStatus]

    public init(
        scope: DeviceStatusScope,
        timestamp: TimeInterval,
        device: DeviceIdentity,
        cpu: DeviceCPUStatus? = nil,
        memory: DeviceMemoryStatus? = nil,
        gpu: DeviceGPUStatus? = nil,
        battery: DeviceBatteryStatus? = nil,
        volumes: [DeviceVolumeStatus] = [],
        thermal: DeviceThermalStatus? = nil,
        processes: [DeviceProcessStatus] = []
    ) {
        self.scope = scope
        self.timestamp = timestamp
        self.device = device
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.battery = battery
        self.volumes = volumes
        self.thermal = thermal
        self.processes = processes
    }

    /// 采样时间。
    public var date: Date {
        Date(timeIntervalSince1970: timestamp)
    }
}
