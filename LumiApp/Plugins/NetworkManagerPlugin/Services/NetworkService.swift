import Foundation
import SystemConfiguration
import Darwin
import MagicKit
import Combine

@MainActor
class NetworkService: SuperLog, ObservableObject {
    nonisolated static let emoji = "📡"
    nonisolated static let verbose: Bool = false
    static let shared = NetworkService()

    private final class LockedDataBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let copy = data
            lock.unlock()
            return copy
        }
    }

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
            NetworkManagerPlugin.logger.info("\(Self.t)NetworkService initialized")
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
            if Self.verbose {
                NetworkManagerPlugin.logger.info("\(Self.t)Starting network monitoring")
            }
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
            if Self.verbose {
                NetworkManagerPlugin.logger.info("\(Self.t)Stopping network monitoring")
            }
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
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // Usually Wi-Fi
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    return String(cString: hostname)
                }
            }
            ptr = interface.ifa_next
        }
        return nil
    }
    
    /// Get Public IP (Async)
    func getPublicIP() async -> String? {
        // 使用备用 API 列表，增加重试机制，避免单一服务故障或 TLS 问题
        // 国内可用服务（纯文本响应）
        let domesticServices = [
            "https://ip.3322.net",
            "https://www.speedtest.cn/api/external.php"
        ]

        // 国际服务（备用）
        let internationalServices = [
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com",
            "https://checkip.amazonaws.com"
        ]

        let services = domesticServices + internationalServices

        // 创建一个不使用缓存的 Session 配置
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 2

        let session = URLSession(configuration: config)

        for service in services {
            guard let url = URL(string: service) else { continue }
            do {
                let (data, response) = try await session.data(from: url)

                // 检查 HTTP 状态码
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    if Self.verbose {
                        NetworkManagerPlugin.logger.info("\(Self.t)⚠️ HTTP 错误：\(service) - 状态码：\(httpResponse.statusCode)")
                    }
                    continue
                }

                let ip = parseIP(from: String(data: data, encoding: .utf8) ?? "")

                if let ip = ip, isValidIPv4(ip) {
                    if Self.verbose {
                        NetworkManagerPlugin.logger.info("\(Self.t)✅ 获取公网 IP 成功：\(ip) (来源：\(service))")
                    }
                    return ip
                }
            } catch {
                if Self.verbose {
                    NetworkManagerPlugin.logger.info("\(Self.t)⚠️ 获取公网 IP 失败：\(service) - \(error.localizedDescription)")
                }
                continue
            }
        }

        NetworkManagerPlugin.logger.error("\(Self.t)❌ 所有公网 IP 服务均不可用")
        return nil
    }

    /// 从响应中解析 IP 地址
    private func parseIP(from response: String) -> String? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // 尝试直接匹配 IPv4 格式
        let ipPattern = #"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#
        let regex = try? NSRegularExpression(pattern: ipPattern)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if let match = regex?.firstMatch(in: trimmed, range: range) {
            return String(trimmed[Range(match.range, in: trimmed)!])
        }

        return nil
    }

    /// 验证是否为有效的 IPv4 地址
    private func isValidIPv4(_ ip: String) -> Bool {
        let pattern = #"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: ip)
    }
    
    /// Get Wi-Fi Info (SSID, RSSI) via airport utility
    func getWifiInfo() async -> (ssid: String?, rssi: Int) {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport")
            process.arguments = ["-I"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                let buffer = LockedDataBuffer()
                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { h in
                    let chunk = h.availableData
                    if !chunk.isEmpty { buffer.append(chunk) }
                }

                await withCheckedContinuation { continuation in
                    process.terminationHandler = { _ in
                        continuation.resume()
                    }
                }

                handle.readabilityHandler = nil
                let final = handle.availableData
                if !final.isEmpty { buffer.append(final) }
                if let output = String(data: buffer.snapshot(), encoding: .utf8) {
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
                return (nil, 0)
            }
            return (nil, 0)
        }.value
    }
    
    /// Simple Ping Test
    func ping(host: String = "8.8.8.8") async -> Double {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "1", host] // count 1, timeout 1s

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                let buffer = LockedDataBuffer()
                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { h in
                    let chunk = h.availableData
                    if !chunk.isEmpty { buffer.append(chunk) }
                }

                await withCheckedContinuation { continuation in
                    process.terminationHandler = { _ in
                        continuation.resume()
                    }
                }

                handle.readabilityHandler = nil
                let final = handle.availableData
                if !final.isEmpty { buffer.append(final) }
                if let output = String(data: buffer.snapshot(), encoding: .utf8) {
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
        }.value
    }
}
