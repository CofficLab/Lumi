import Foundation

struct NetworkState: Equatable {
    var uploadSpeed: Double = 0 // Bytes/s
    var downloadSpeed: Double = 0 // Bytes/s
    var totalUpload: UInt64 = 0
    var totalDownload: UInt64 = 0
    var publicIP: String?
    var localIP: String?
    var interfaceName: String = "en0"
    var wifiSSID: String?
    var wifiSignalStrength: Int = 0 // RSSI
    var ping: Double = 0 // ms
}

struct NetworkInterfaceInfo: Identifiable {
    let id = UUID()
    let name: String
    let ip: String
    let mac: String
    let isActive: Bool
}

struct ProcessNetworkInfo: Identifiable {
    let id = UUID()
    let pid: Int
    let name: String
    let icon: URL?
    // Note: Real-time per-process speed is hard without NetworkExtension, 
    // we will store connection count or accumulated bytes if available via nettop
    var connectionCount: Int = 0
}
