import Foundation
import SwiftUI

/// Owns the port list and the refresh/kill orchestration for `PortManagerView`.
///
/// Scans are asynchronous and can complete out of order: a refresh started
/// before a kill may finish after the post-kill refresh and re-insert the
/// killed process. Every refresh therefore captures a `scanGeneration`, and
/// only the newest generation may write the list, the error state, or the
/// loading flag; a successful kill immediately invalidates any in-flight
/// pre-kill scan (issue #247).
@MainActor
public final class PortManagerViewModel: ObservableObject {
    @Published public private(set) var ports: [PortInfo] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    private let scanner: any PortScanning
    private var scanGeneration = 0

    public init(scanner: any PortScanning = PortScanner.shared) {
        self.scanner = scanner
    }

    public func refresh() async {
        scanGeneration += 1
        let generation = scanGeneration
        isLoading = true
        do {
            let scanned = try await scanner.scanPorts()
            guard generation == scanGeneration else { return }
            ports = scanned
            showError = false
            isLoading = false
        } catch {
            guard generation == scanGeneration else { return }
            ports = []
            errorMessage = String(
                format: pluginLocalization.string("Failed to scan ports: %@"),
                error.localizedDescription
            )
            showError = true
            isLoading = false
        }
    }

    public func killProcess(_ port: PortInfo) async {
        let generation = scanGeneration
        do {
            try await scanner.killProcess(port)
        } catch {
            if generation == scanGeneration {
                errorMessage = pluginLocalization.string("Failed to kill process: \(error.localizedDescription)")
                showError = true
            }
            // 拒绝 kill（进程已退出 / PID 被复用 / 端口归属变化）后刷新列表，
            // 避免用户继续基于过期行操作（#246）。
            await refresh()
            return
        }
        // kill 成功：立即作废仍在途的 kill 前扫描，其旧快照不得让被杀进程
        // 复活，也不得替新回合清掉 loading（#247）。
        scanGeneration += 1
        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s
        await refresh()
    }
}