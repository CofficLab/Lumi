import Foundation
import SuperLogKit
import HttpKit
import SystemConfiguration
import Darwin
import Combine
import ShellKit

@MainActor
public class NetworkService: SuperLog, ObservableObject {
    public nonisolated static let emoji = "📡"
    public nonisolated static let verbose: Bool = true
    public static let shared = NetworkService()

    // Published properties for subscribers
    @Published var downloadSpeed: Double = 0
    @Published var uploadSpeed: Double = 0
    @Published var totalDownload: UInt64 = 0
    @Published var totalUpload: UInt64 = 0
    
    // Monitoring state
    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    /// 心跳节流计数：每次网络采样 tick 自增，每 N 次打一条日志（1Hz → 约每 10 秒一条）。
    /// 用于排查 CPU 占用持续 100% 时确认本采样链路是否在持续运行。
    private var tickCount = 0
    private let tickLogEvery = 10

    // Previous data for speed calculation
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastCheckTime: TimeInterval = 0

    private init() {
        if Self.verbose {
            if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.info("\(Self.t)NetworkService initialized")
            }
        }

        // Initialize baseline
        let (In, Out) = Self.getInterfaceCounters()
        lastBytesIn = In
        lastBytesOut = Out
        lastCheckTime = Date().timeIntervalSince1970
    }
    
    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                if NetworkManagerPlugin.verbose {
                                    NetworkManagerPlugin.logger.info("\(Self.t)Starting network monitoring")
                }
            }
            // Reset baseline to avoid huge spike if paused for long time
            let (In, Out) = Self.getInterfaceCounters()
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
    
    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                if NetworkManagerPlugin.verbose {
                                    NetworkManagerPlugin.logger.info("\(Self.t)Stopping network monitoring")
                }
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
        }
    }
    
    /// Internal update loop
    private func updateNetworkUsage() {
        guard samplingTask == nil else { return }

        let currentTime = Date().timeIntervalSince1970
        let previousBytesIn = lastBytesIn
        let previousBytesOut = lastBytesOut
        let previousCheckTime = lastCheckTime

        samplingTask = Task.detached(priority: .utility) { [currentTime, previousBytesIn, previousBytesOut, previousCheckTime] in
            let (currentIn, currentOut) = Self.getInterfaceCounters()
            let timeDelta = currentTime - previousCheckTime

            var downloadSpeed: Double = 0
            var uploadSpeed: Double = 0

            if timeDelta > 0 {
                // Handle wrap-around or reset
                if currentIn >= previousBytesIn {
                    downloadSpeed = Double(currentIn - previousBytesIn) / timeDelta
                }
                if currentOut >= previousBytesOut {
                    uploadSpeed = Double(currentOut - previousBytesOut) / timeDelta
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }

                self.lastBytesIn = currentIn
                self.lastBytesOut = currentOut
                self.lastCheckTime = currentTime
                self.downloadSpeed = downloadSpeed
                self.uploadSpeed = uploadSpeed
                self.totalDownload = currentIn
                self.totalUpload = currentOut

                // 节流心跳：确认 1Hz 网络采样链路在持续运行。
                self.tickCount += 1
                if Self.verbose, NetworkManagerPlugin.verbose, self.tickCount % self.tickLogEvery == 0 {
                    NetworkManagerPlugin.logger.info("\(self.t)tick #\(self.tickCount) 采样完成，↓\(String(format: "%.0f", downloadSpeed))B/s ↑\(String(format: "%.0f", uploadSpeed))B/s")
                }
            }
        }
    }
    
    /// Get current network speeds (bytes/s) and total bytes (Legacy/Direct Access)
    /// Note: Calling this manually might interfere with the automatic monitoring if not careful,
    /// but we keep it for one-off checks if needed.
    public func getNetworkUsage() -> (downloadSpeed: Double, uploadSpeed: Double, totalDownload: UInt64, totalUpload: UInt64) {
        // If monitoring is active, return cached values to avoid messing up the delta
        if monitoringTimer != nil {
            return (downloadSpeed, uploadSpeed, totalDownload, totalUpload)
        }
        
        // Otherwise perform a manual check (which updates state)
        updateNetworkUsage()
        return (downloadSpeed, uploadSpeed, totalDownload, totalUpload)
    }
    
    /// Get aggregated bytes In/Out from all interfaces
    private nonisolated static func getInterfaceCounters() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while let current = ptr {
            let interface = current.pointee
            guard let address = interface.ifa_addr else {
                ptr = interface.ifa_next
                continue
            }
            
            // Only look at AF_LINK (link layer) for statistics
            if address.pointee.sa_family == UInt8(AF_LINK) {
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
    public func getLocalIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while let current = ptr {
            let interface = current.pointee
            guard let address = interface.ifa_addr else {
                ptr = interface.ifa_next
                continue
            }
            let addrFamily = address.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // Usually Wi-Fi
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(address, socklen_t(address.pointee.sa_len),
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
    public func getPublicIP() async -> String? {
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

        // 使用 HttpKit 的 ephemeral 配置客户端
        let client = HTTPClient(timeoutIntervalForRequest: 2, timeoutIntervalForResource: 2) { config in
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
        }

        for service in services {
            guard let url = URL(string: service) else { continue }
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                let data = try await client.sendRequest(request: request)

                let ip = parseIP(from: String(data: data, encoding: .utf8) ?? "")

                if let ip = ip, isValidIPv4(ip) {
                    if Self.verbose {
                        if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.info("\(Self.t)✅ 获取公网 IP 成功：\(ip) (来源：\(service))")
                        }
                    }
                    return ip
                }
            } catch {
                if Self.verbose {
                    if NetworkManagerPlugin.verbose {
                        NetworkManagerPlugin.logger.info("\(Self.t)⚠️ 获取公网 IP 失败：\(service) - \(error.localizedDescription)")
                    }
                }
                continue
            }
        }

        if NetworkManagerPlugin.verbose {
            NetworkManagerPlugin.logger.error("\(Self.t)❌ 所有公网 IP 服务均不可用")
        }
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
    public func getWifiInfo() async -> (ssid: String?, rssi: Int) {
        do {
            let result = try await Shell.execute(
                executable: "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
                arguments: ["-I"],
                options: ShellOptions(qos: .utility, throwsOnError: false)
            )
            guard result.exitCode == 0 else { return (nil, 0) }

            var ssid: String?
            var rssi: Int = 0
            let lines = result.stdout.components(separatedBy: .newlines)
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
        } catch {
            return (nil, 0)
        }
    }
    
    /// Simple Ping Test
    public func ping(host: String = "8.8.8.8") async -> Double {
        do {
            let result = try await Shell.execute(
                executable: "/sbin/ping",
                arguments: ["-c", "1", "-t", "1", host],
                options: ShellOptions(qos: .utility, throwsOnError: false)
            )
            guard result.exitCode == 0 else { return 0 }
            if let range = result.stdout.range(of: "time=") {
                let substring = result.stdout[range.upperBound...]
                let components = substring.components(separatedBy: " ")
                if let msString = components.first, let ms = Double(msString) {
                    return ms
                }
            }
            return 0
        } catch {
            return 0
        }
    }
}
