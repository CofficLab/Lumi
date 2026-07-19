import Foundation

// MARK: - Monitoring Data Models

public struct SystemMetrics: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let cpuUsage: ResourceUsage
    public let memoryUsage: ResourceUsage
    public let network: NetworkMetrics
    public let disk: DiskMetrics

    public init(
        timestamp: Date,
        cpuUsage: ResourceUsage,
        memoryUsage: ResourceUsage,
        network: NetworkMetrics,
        disk: DiskMetrics
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.network = network
        self.disk = disk
    }

    public static var empty: SystemMetrics {
        SystemMetrics(
            timestamp: Date(),
            cpuUsage: .empty,
            memoryUsage: .empty,
            network: .empty,
            disk: .empty
        )
    }
}

public struct ResourceUsage: Equatable {
    public let percentage: Double // 0.0 - 1.0
    public let description: String // e.g., "4.5 GB / 16 GB" or "15%"
    public let history: [Double] // For drawing charts (0.0 - 1.0)

    public init(percentage: Double, description: String, history: [Double]) {
        self.percentage = percentage
        self.description = description
        self.history = history
    }

    public static var empty: ResourceUsage {
        ResourceUsage(percentage: 0, description: LumiPluginLocalization.string("--", bundle: .module), history: [])
    }
}

public struct NetworkMetrics: Equatable {
    public let uploadSpeed: Double // bytes per second
    public let downloadSpeed: Double // bytes per second
    public let uploadHistory: [Double]
    public let downloadHistory: [Double]

    public init(uploadSpeed: Double, downloadSpeed: Double, uploadHistory: [Double], downloadHistory: [Double]) {
        self.uploadSpeed = uploadSpeed
        self.downloadSpeed = downloadSpeed
        self.uploadHistory = uploadHistory
        self.downloadHistory = downloadHistory
    }

    public var uploadSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(uploadSpeed), countStyle: .binary) + "/s"
    }

    public var downloadSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .binary) + "/s"
    }

    public static var empty: NetworkMetrics {
        NetworkMetrics(uploadSpeed: 0, downloadSpeed: 0, uploadHistory: [], downloadHistory: [])
    }
}

public struct DiskMetrics: Equatable {
    public let readSpeed: Double // bytes per second
    public let writeSpeed: Double // bytes per second
    public let readHistory: [Double]
    public let writeHistory: [Double]

    public init(readSpeed: Double, writeSpeed: Double, readHistory: [Double], writeHistory: [Double]) {
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.readHistory = readHistory
        self.writeHistory = writeHistory
    }

    public var readSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(readSpeed), countStyle: .binary) + "/s"
    }

    public var writeSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(writeSpeed), countStyle: .binary) + "/s"
    }

    public static var empty: DiskMetrics {
        DiskMetrics(readSpeed: 0, writeSpeed: 0, readHistory: [], writeHistory: [])
    }
}

// MARK: - Process Monitoring Models

public struct ProcessMetric: Identifiable, Hashable, Sendable {
    public let id: Int32 // PID
    public let name: String
    public let icon: String? // Bundle path or similar
    public let cpuUsage: Double
    public let memoryUsage: Int64

    public init(id: Int32, name: String, icon: String?, cpuUsage: Double, memoryUsage: Int64) {
        self.id = id
        self.name = name
        self.icon = icon
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }

    public var memoryString: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}
