import Foundation
import SystemConfiguration
import Darwin
import OSLog
import MagicKit
import Combine

@MainActor
class NetworkService: SuperLog, ObservableObject {
    nonisolated static let emoji = "📡"
    nonisolated static let verbose = true

    static let shared = NetworkService()

    // Published properties for subscribers
    @Published var downloadSpeed: Double = 0
    @Published var uploadSpeed: Double = 0
    @Published var totalDownload: UInt64 = 0
    @Published var totalUpload: UInt64 = 0
    
    // Monitoring state
    private var monitoringTimer: Timer?
    private var subscribersCount = 0

    // Previous data for speed calculation
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastCheckTime: TimeInterval = 0

    private init() {
        if Self.verbose {
            os_log("\(self.t)NetworkService initialized")
        }

        // Initialize baseline
        let (In, Out) = getInterfaceCounters()
        lastBytesIn = In
        lastBytesOut = Out
        lastCheckTime = Date().timeIntervalSince1970
    }
    
    func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            os_log("\(self.t)Starting network monitoring")
            // Reset baseline to avoid huge spike if paused for long time
            let (In, Out) = getInterfaceCounters()
            lastBytesIn = In
            lastBytesOut = Out
            lastCheckTime = Date().timeIntervalSince1970
            
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateNetworkUsage()
                }
            }
        }
    }
    
    func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            os_log("\(self.t)Stopping network monitoring")
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
    
    /// Internal update loop
    private func updateNetworkUsage() {
        let currentTime = Date().timeIntervalSince1970
        let (currentIn, currentOut) = getInterfaceCounters()
        
        let timeDelta = currentTime - lastCheckTime
        
        var dSpeed: Double = 0
        var uSpeed: Double = 0
        
        if timeDelta > 0 {
            // Handle wrap-around or reset
            if currentIn >= lastBytesIn {
                dSpeed = Double(currentIn - lastBytesIn) / timeDelta
            }
            if currentOut >= lastBytesOut {
                uSpeed = Double(currentOut - lastBytesOut) / timeDelta
            }
        }
        
        // Update state
        lastBytesIn = currentIn
        lastBytesOut = currentOut
        lastCheckTime = currentTime

        // Publish updates
        downloadSpeed = dSpeed
        uploadSpeed = uSpeed
        totalDownload = currentIn
        totalUpload = currentOut
    }
    
    /// Get current network speeds (bytes/s) and total bytes (Legacy/Direct Access)
    /// Note: Calling this manually might interfere with the automatic monitoring if not careful,
    /// but we keep it for one-off checks if needed.
    func getNetworkUsage() -> (downloadSpeed: Double, uploadSpeed: Double, totalDownload: UInt64, totalUpload: UInt64) {
        // If monitoring is active, return cached values to avoid messing up the delta
        if monitoringTimer != nil {
            return (downloadSpeed, uploadSpeed, totalDownload, totalUpload)
        }
        
        // Otherwise perform a manual check (which updates state)
        updateNetworkUsage()
        return (downloadSpeed, uploadSpeed, totalDownload, totalUpload)
    }
    
    /// Get aggregated bytes In/Out from all interfaces
    private func getInterfaceCounters() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            
            // Only look at AF_LINK (link layer) for statistics
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                
                // Filter loopback and inactive interfaces if needed
                // For "Total", we usually sum en0, en1, etc.
                if name.hasPrefix("en") || name.hasPrefix("wi") {
                    if let data = interface.ifa_data {
                        let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                        totalIn += UInt64(networkData.ifi_ibytes)
                        totalOut += UInt64(networkData.ifi_obytes)
                    }
                }
            }
            ptr = interface.ifa_next
        }
        
        return (totalIn, totalOut)
    }
    
    /// Get Local IP Address
    func getLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(validatingCString: interface.ifa_name) ?? ""
                if name == "en0" { // Usually Wi-Fi
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    return String(validatingCString: hostname) ?? ""
                }
            }
            ptr = interface.ifa_next
        }
        return nil
    }
    
    /// Get Public IP (Async)
    func getPublicIP() async -> String? {
        // 使用备用 API 列表，增加重试机制，避免单一服务故障或 TLS 问题
        let services = [
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com",
            "https://checkip.amazonaws.com"
        ]
        
        // 创建一个不使用缓存的 Session 配置
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        
        let session = URLSession(configuration: config)
        
        for service in services {
            guard let url = URL(string: service) else { continue }
            do {
                let (data, _) = try await session.data(from: url)
                let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let ip = ip, !ip.isEmpty {
                    return ip
                }
            } catch {
                if Self.verbose {
                    os_log(.error, "\(self.t)Failed to get public IP from \(service): \(error.localizedDescription)")
                }
                continue
            }
        }
        return nil
    }
    
    /// Get Wi-Fi Info (SSID, RSSI) via airport utility
    func getWifiInfo() -> (ssid: String?, rssi: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport")
        process.arguments = ["-I"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var ssid: String?
                var rssi: Int = 0
                
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("SSID:") {
                        ssid = trimmed.replacingOccurrences(of: "SSID: ", with: "")
                    } else if trimmed.hasPrefix("agrCtlRSSI:") {
                        if let val = Int(trimmed.replacingOccurrences(of: "agrCtlRSSI: ", with: "")) {
                            rssi = val
                        }
                    }
                }
                return (ssid, rssi)
            }
        } catch {
            // Ignore error
        }
        return (nil, 0)
    }
    
    /// Simple Ping Test
    func ping(host: String = "8.8.8.8") async -> Double {
        // Ping is tricky to parse accurately across OS versions, but let's try basic one packet
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-t", "1", host] // count 1, timeout 1s
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse "time=12.345 ms"
                if let range = output.range(of: "time=") {
                    let substring = output[range.upperBound...]
                    let components = substring.components(separatedBy: " ")
                    if let msString = components.first, let ms = Double(msString) {
                        return ms
                    }
                }
            }
        } catch {
            return 0
        }
        return 0
    }
}
