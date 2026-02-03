import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class NetworkManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "🌐"
    static let verbose = false

    @Published var networkState = NetworkState()
    @Published var interfaces: [NetworkInterfaceInfo] = []
    
    // 进程监控相关
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

    // 系统启动时间
    var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        return formatUptime(uptime)
    }

    var filteredProcesses: [NetworkProcess] {
        var result = processes
        
        // 1. 活跃过滤 (> 0 bytes/s)
        if onlyActiveProcesses {
            result = result.filter { $0.totalSpeed > 0 }
        }
        
        // 2. 搜索过滤
        if !processSearchText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(processSearchText) ||
                String($0.id).contains(processSearchText)
            }
        }
        
        // 3. 排序 (默认按总速度降序)
        result.sort { $0.totalSpeed > $1.totalSpeed }
        
        return result
    }

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        if Self.verbose {
            os_log("\(self.t)网络管理视图模型已初始化")
        }
        startMonitoring()
        
        // 绑定服务回调
        ProcessMonitorService.shared.onUpdate = { [weak self] newProcesses in
            Task { @MainActor in
                self?.processes = newProcesses
            }
        }
    }
    
    deinit {
        NetworkService.shared.stopMonitoring()
        timer?.invalidate()
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
            os_log("\(self.t)开始网络监控")
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
        
        // Public IP (only if missing or periodically refreshed rarely, here we do it every 10s which might be too much for API limits, let's optimize)
        if networkState.publicIP == nil {
            networkState.publicIP = await NetworkService.shared.getPublicIP()
        }
    }
    
    // Formatting Helpers
    func formatSpeed(_ bytesPerSec: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSec)) + "/s"
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = Int(seconds) / 3600 % 24
        let minutes = Int(seconds) / 60 % 60

        if days > 0 {
            return "\(days)天 \(hours)小时 \(minutes)分钟"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
