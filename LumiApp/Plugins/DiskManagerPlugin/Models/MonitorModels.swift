import Foundation

// MARK: - Monitoring Data Models

struct SystemMetrics: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let cpuUsage: ResourceUsage
    let memoryUsage: ResourceUsage
    let network: NetworkMetrics
    let disk: DiskMetrics
    
    static var empty: SystemMetrics {
        SystemMetrics(
            timestamp: Date(),
            cpuUsage: .empty,
            memoryUsage: .empty,
            network: .empty,
            disk: .empty
        )
    }
}

struct ResourceUsage: Equatable {
    let percentage: Double // 0.0 - 1.0
    let description: String // e.g., "4.5 GB / 16 GB" or "15%"
    let history: [Double] // For drawing charts (0.0 - 1.0)
    
    static var empty: ResourceUsage {
        ResourceUsage(percentage: 0, description: "--", history: [])
    }
}

struct NetworkMetrics: Equatable {
    let uploadSpeed: Double // bytes per second
    let downloadSpeed: Double // bytes per second
    let uploadHistory: [Double]
    let downloadHistory: [Double]
    
    var uploadSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(uploadSpeed), countStyle: .binary) + "/s"
    }
    
    var downloadSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadSpeed), countStyle: .binary) + "/s"
    }
    
    static var empty: NetworkMetrics {
        NetworkMetrics(uploadSpeed: 0, downloadSpeed: 0, uploadHistory: [], downloadHistory: [])
    }
}

struct DiskMetrics: Equatable {
    let readSpeed: Double // bytes per second
    let writeSpeed: Double // bytes per second
    let readHistory: [Double]
    let writeHistory: [Double]
    
    var readSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(readSpeed), countStyle: .binary) + "/s"
    }
    
    var writeSpeedString: String {
        ByteCountFormatter.string(fromByteCount: Int64(writeSpeed), countStyle: .binary) + "/s"
    }
    
    static var empty: DiskMetrics {
        DiskMetrics(readSpeed: 0, writeSpeed: 0, readHistory: [], writeHistory: [])
    }
}

// MARK: - Process Monitoring Models

struct ProcessMetric: Identifiable, Hashable {
    let id: Int32 // PID
    let name: String
    let icon: String? // Bundle path or similar
    let cpuUsage: Double
    let memoryUsage: Int64
    
    var memoryString: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}
