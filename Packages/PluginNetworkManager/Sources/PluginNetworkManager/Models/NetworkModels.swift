import Foundation

public struct NetworkState: Equatable {
    public var uploadSpeed: Double = 0 // Bytes/s
    public var downloadSpeed: Double = 0 // Bytes/s
    public var totalUpload: UInt64 = 0
    public var totalDownload: UInt64 = 0
    public var publicIP: String?
    public var localIP: String?
    public var interfaceName: String = "en0"
    public var wifiSSID: String?
    public var wifiSignalStrength: Int = 0 // RSSI
    public var ping: Double = 0 // ms
}

public struct NetworkInterfaceInfo: Identifiable {
    public let id = UUID()
    public let name: String
    public let ip: String
    public let mac: String
    public let isActive: Bool
}

public struct ProcessNetworkInfo: Identifiable {
    public let id = UUID()
    public let pid: Int
    public let name: String
    public let icon: URL?
    // Note: Real-time per-process speed is hard without NetworkExtension, 
    // we will store connection count or accumulated bytes if available via nettop
    public var connectionCount: Int = 0
}
