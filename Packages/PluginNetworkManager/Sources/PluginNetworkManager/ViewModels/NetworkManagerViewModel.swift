import Foundation
import LumiLoggingKit
import Combine

@MainActor
public class NetworkManagerViewModel: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = false
    @Published var networkState = NetworkState()
    @Published var interfaces: [NetworkInterfaceInfo] = []

    // 公网 IP 缓存（避免频繁请求）
    private var cachedPublicIP: String?
    private var lastPublicIPFetch: Date?
    private let publicIPCacheDuration: TimeInterval = 300 // 5 分钟缓存
    private let publicIPProvider: @Sendable () async -> String?
    
    // Process monitoring related
    @Published var processes: [NetworkProcess] = []
    /// 是否已经收到至少一个有效的进程采样。
    ///
    /// 首次采样发布前，进程明细应显示「收集数据中」而不是「没有活跃进程」。
    @Published var hasProcessSnapshot = false
    @Published var showProcessMonitor = false {
        didSet {
            guard oldValue != showProcessMonitor else { return }
            if showProcessMonitor {
                startProcessMonitoring()
            } else {
                stopProcessMonitoring()
            }
        }
    }
    // System boot time
    public var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        return formatUptime(uptime)
    }

    public var filteredProcesses: [NetworkProcess] {
        processes
            .filter { $0.totalSpeed > 0 }
            .sorted { $0.totalSpeed > $1.totalSpeed }
    }

    /// 主菜单栏弹窗网络区块内联展示的高占用进程。
    ///
    /// 与 CPU 区块保持一致取前 5 名；仅此处限制条数，不改变详情列表的展示规则。
    /// 同时排除格式化后显示为 `0B/s` 的进程，避免出现「有列表但全是 0」。
    public var topNetworkProcesses: [NetworkProcess] {
        Array(
            filteredProcesses
                .filter { SpeedFormatter.formatForStatusBar($0.totalSpeed) != "0B/s" }
                .prefix(5)
        )
    }

    private var isProcessMonitoringActive = false
    private var processMonitorRequestCount = 0
    private let processMonitoringStarter: @MainActor () -> Void
    private let processMonitoringStopper: @MainActor () -> Void

    public init(
        publicIPProvider: @escaping @Sendable () async -> String? = {
            await NetworkService.shared.getPublicIP()
        },
        processMonitoringStarter: @escaping @MainActor () -> Void = { ProcessMonitorService.shared.startMonitoring() },
        processMonitoringStopper: @escaping @MainActor () -> Void = { ProcessMonitorService.shared.stopMonitoring() }
    ) {
        self.publicIPProvider = publicIPProvider
        self.processMonitoringStarter = processMonitoringStarter
        self.processMonitoringStopper = processMonitoringStopper

        if Self.verbose {
            if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.info("\(self.t)NetworkManagerViewModel initialized")
            }
        }
    }

    public func startProcessMonitoring() {
        guard !isProcessMonitoringActive else { return }
        isProcessMonitoringActive = true
        processMonitoringStarter()
    }
    
    public func stopProcessMonitoring() {
        guard isProcessMonitoringActive else { return }
        isProcessMonitoringActive = false
        processMonitoringStopper()
    }

    /// 请求保持进程监控运行（引用计数）。
    ///
    /// 主弹窗的内联进程列表与悬停详情浮层会同时可见，
    /// 用引用计数避免其中一个消失时把 nettop 提前关掉。
    public func acquireProcessMonitor() {
        processMonitorRequestCount += 1
        guard processMonitorRequestCount == 1 else { return }
        showProcessMonitor = true
    }

    /// 释放一次进程监控请求；计数归零时才真正停止 nettop。
    public func releaseProcessMonitor() {
        guard processMonitorRequestCount > 0 else { return }
        processMonitorRequestCount -= 1
        guard processMonitorRequestCount == 0 else { return }
        showProcessMonitor = false
    }

    public func updateProcesses(_ processes: [NetworkProcess]) {
        self.processes = processes
    }

    public func updateProcessSnapshotReady(_ isReady: Bool) {
        hasProcessSnapshot = isReady
    }

    // Removed updateStats() as it is replaced by Combine subscription

    func applyNetworkUsage(
        downloadSpeed: Double,
        uploadSpeed: Double,
        totalDownload: UInt64,
        totalUpload: UInt64
    ) {
        var updatedState = networkState
        updatedState.downloadSpeed = downloadSpeed
        updatedState.uploadSpeed = uploadSpeed
        updatedState.totalDownload = totalDownload
        updatedState.totalUpload = totalUpload
        networkState = updatedState
    }
    
    func applySlowStats(wifiSSID: String?, wifiSignalStrength: Int, ping: Double, localIP: String?, publicIP: String?) {
        var updatedState = networkState
        updatedState.wifiSSID = wifiSSID
        updatedState.wifiSignalStrength = wifiSignalStrength
        updatedState.ping = ping
        updatedState.localIP = localIP
        if let publicIP { updatedState.publicIP = publicIP }
        networkState = updatedState
    }

    func updateSlowStats() async {
        // WiFi
        let (ssid, rssi) = await NetworkService.shared.getWifiInfo()
        var updatedState = networkState
        updatedState.wifiSSID = ssid
        updatedState.wifiSignalStrength = rssi

        // Ping
        let latency = await NetworkService.shared.ping()
        updatedState.ping = latency

        // Local IP
        updatedState.localIP = NetworkService.shared.getLocalIP()

        if let cachedIP = cachedPublicIP {
            updatedState.publicIP = cachedIP
        }

        applySlowStats(
            wifiSSID: updatedState.wifiSSID,
            wifiSignalStrength: updatedState.wifiSignalStrength,
            ping: updatedState.ping,
            localIP: updatedState.localIP,
            publicIP: updatedState.publicIP
        )
    }

    public func refreshPublicIPIfNeeded(force: Bool = false) async {
        let shouldFetchPublicIP: Bool
        if force {
            shouldFetchPublicIP = true
        } else if let lastFetch = lastPublicIPFetch {
            shouldFetchPublicIP = Date().timeIntervalSince(lastFetch) > publicIPCacheDuration
        } else {
            shouldFetchPublicIP = true
        }

        if shouldFetchPublicIP {
            if let ip = await publicIPProvider() {
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
    public func formatUptime(_ seconds: TimeInterval) -> String {
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
