import Foundation
import SuperLogKit
import Combine

@MainActor
public class NetworkManagerViewModel: ObservableObject, SuperLog {
    public static let shared = NetworkManagerViewModel()

    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true
    @Published var networkState = NetworkState()
    @Published var interfaces: [NetworkInterfaceInfo] = []

    // 公网 IP 缓存（避免频繁请求）
    private var cachedPublicIP: String?
    private var lastPublicIPFetch: Date?
    private let publicIPCacheDuration: TimeInterval = 300 // 5 分钟缓存
    private let publicIPProvider: @Sendable () async -> String?
    
    // Process monitoring related
    @Published var processes: [NetworkProcess] = []
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
    @Published var onlyActiveProcesses = true
    @Published var processSearchText = ""

    // System boot time
    public var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        return formatUptime(uptime)
    }

    public var filteredProcesses: [NetworkProcess] {
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
    private var isMonitoring = false
    private var isProcessMonitoringActive = false
    private var networkCancellables = Set<AnyCancellable>()
    private var processCancellables = Set<AnyCancellable>()
    private let processMonitoringStarter: @MainActor () -> Void
    private let processMonitoringStopper: @MainActor () -> Void

    public init(
        autoStartMonitoring: Bool = true,
        publicIPProvider: @escaping @Sendable () async -> String? = {
            await NetworkService.shared.getPublicIP()
        },
        processMonitoringStarter: @escaping @MainActor () -> Void = {
            ProcessMonitorService.shared.startMonitoring()
        },
        processMonitoringStopper: @escaping @MainActor () -> Void = {
            ProcessMonitorService.shared.stopMonitoring()
        }
    ) {
        self.publicIPProvider = publicIPProvider
        self.processMonitoringStarter = processMonitoringStarter
        self.processMonitoringStopper = processMonitoringStopper

        if Self.verbose {
            if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.info("\(self.t)NetworkManagerViewModel initialized")
            }
        }
        if autoStartMonitoring {
            startMonitoring()
        }
    }

    private func bindProcessUpdatesIfNeeded() {
        guard processCancellables.isEmpty else { return }

        ProcessMonitorService.shared.$processes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processes in
                if Self.verbose {
                    if NetworkManagerPlugin.verbose {
                                            NetworkManagerPlugin.logger.info("\(self?.t ?? NetworkManagerViewModel.t)Received process updates: \(processes.count)")
                    }
                }
                self?.processes = processes
            }
            .store(in: &processCancellables)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopProcessMonitoring()
            self?.stopMonitoring()
        }
    }
    
    public func startProcessMonitoring() {
        guard !isProcessMonitoringActive else { return }
        isProcessMonitoringActive = true
        bindProcessUpdatesIfNeeded()
        processMonitoringStarter()
    }
    
    public func stopProcessMonitoring() {
        guard isProcessMonitoringActive else { return }
        isProcessMonitoringActive = false
        processMonitoringStopper()
        processCancellables.removeAll()
        processes = []
    }

    public func updateProcesses(_ processes: [NetworkProcess]) {
        self.processes = processes
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        if Self.verbose {
            if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.info("\(self.t)Starting network monitoring")
            }
        }

        // Subscribe to NetworkService updates
        NetworkService.shared.startMonitoring()

        NetworkService.shared.$downloadSpeed
            .combineLatest(NetworkService.shared.$uploadSpeed, NetworkService.shared.$totalDownload, NetworkService.shared.$totalUpload)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (down, up, totalDown, totalUp) in
                self?.applyNetworkUsage(
                    downloadSpeed: down,
                    uploadSpeed: up,
                    totalDownload: totalDown,
                    totalUpload: totalUp
                )
            }
            .store(in: &networkCancellables)

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

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        timer?.invalidate()
        timer = nil
        networkCancellables.removeAll()
        NetworkService.shared.stopMonitoring()
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
    
    private func updateSlowStats() async {
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

        networkState = updatedState
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
