import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class NetworkManagerViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    @Published var networkState = NetworkState()
    @Published var interfaces: [NetworkInterfaceInfo] = []

    // 公网 IP 缓存（避免频繁请求）
    private var cachedPublicIP: String?
    private var lastPublicIPFetch: Date?
    private let publicIPCacheDuration: TimeInterval = 300 // 5 分钟缓存
    
    // Process monitoring related
    @Published var processes: [NetworkProcess] = []
    @Published var showProcessMonitor = false {
        didSet {
            if showProcessMonitor {
                startProcessMonitoring()
            } else {
                stopProcessMonitoring()
            }
        }
    }
    @Published var onlyActiveProcesses = true
    @Published var processSearchText = ""

    // System boot time
    var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        return formatUptime(uptime)
    }

    var filteredProcesses: [NetworkProcess] {
        var result = processes
        
        // 1. Activity filtering (> 0 bytes/s)
        if onlyActiveProcesses {
            result = result.filter { $0.totalSpeed > 0 }
        }
        
        // 2. Search filtering
        if !processSearchText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(processSearchText) ||
                String($0.id).contains(processSearchText)
            }
        }
        
        // 3. Sorting (Default by total speed descending)
        result.sort { $0.totalSpeed > $1.totalSpeed }
        
        return result
    }

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        if Self.verbose {
            os_log("\(self.t)NetworkManagerViewModel initialized")
        }
        startMonitoring()
        
        // Bind service data
        ProcessMonitorService.shared.$processes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processes in
                if Self.verbose {
                    os_log("\(self?.t ?? "")Received process updates: \(processes.count)")
                }
                self?.processes = processes
            }
            .store(in: &cancellables)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.timer?.invalidate()
            NetworkService.shared.stopMonitoring()
        }
    }
    
    func startProcessMonitoring() {
        ProcessMonitorService.shared.startMonitoring()
    }
    
    func stopProcessMonitoring() {
        ProcessMonitorService.shared.stopMonitoring()
    }

    func updateProcesses(_ processes: [NetworkProcess]) {
        self.processes = processes
    }

    func startMonitoring() {
        if Self.verbose {
            os_log("\(self.t)Starting network monitoring")
        }

        // Subscribe to NetworkService updates
        NetworkService.shared.startMonitoring()

        NetworkService.shared.$downloadSpeed
            .combineLatest(NetworkService.shared.$uploadSpeed, NetworkService.shared.$totalDownload, NetworkService.shared.$totalUpload)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (down, up, totalDown, totalUp) in
                self?.networkState.downloadSpeed = down
                self?.networkState.uploadSpeed = up
                self?.networkState.totalDownload = totalDown
                self?.networkState.totalUpload = totalUp
            }
            .store(in: &cancellables)

        // Initial slow fetch
        Task {
            await updateSlowStats()
        }

        // Slower update for IP/WiFi/Ping (every 10s)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateSlowStats()
            }
        }
    }
    
    // Removed updateStats() as it is replaced by Combine subscription
    
    private func updateSlowStats() async {
        // WiFi
        let (ssid, rssi) = NetworkService.shared.getWifiInfo()
        networkState.wifiSSID = ssid
        networkState.wifiSignalStrength = rssi

        // Ping
        let latency = await NetworkService.shared.ping()
        networkState.ping = latency

        // Local IP
        networkState.localIP = NetworkService.shared.getLocalIP()

        // Public IP - 使用缓存机制，避免频繁请求
        // 只在以下情况获取：
        // 1. 从未获取过
        // 2. 缓存已过期（> 5 分钟）
        let shouldFetchPublicIP: Bool
        if let lastFetch = lastPublicIPFetch {
            shouldFetchPublicIP = Date().timeIntervalSince(lastFetch) > publicIPCacheDuration
        } else {
            shouldFetchPublicIP = true
        }

        if shouldFetchPublicIP {
            if let ip = await NetworkService.shared.getPublicIP() {
                networkState.publicIP = ip
                cachedPublicIP = ip
                lastPublicIPFetch = Date()
            }
        } else if let cachedIP = cachedPublicIP {
            networkState.publicIP = cachedIP
        }
    }

    // Formatting Helpers
    /// Format uptime duration
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted string
    func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = Int(seconds) / 3600 % 24
        let minutes = Int(seconds) / 60 % 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
