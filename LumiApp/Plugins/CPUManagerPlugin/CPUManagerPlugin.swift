import MagicKit
import SwiftUI
import os

actor CPUManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.cpu-manager")
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🧠"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    
    static let id = "CPUManager"
    static let navigationId: String? = nil
    static let displayName = String(localized: "CPU Monitor", table: "CPUManager")
    static let description = String(localized: "Real-time CPU usage and load monitoring", table: "CPUManager")
    static let iconName = "cpu"
    static var order: Int { 31 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = CPUManagerPlugin()
    
    // MARK: - Lifecycle
    
    init() {
        Task { @MainActor in
            // Start background history recording
            CPUHistoryService.shared.startRecording()
        }
    }
    
    // MARK: - UI
    
    @MainActor func addStatusBarPopupView() -> AnyView? {
        return AnyView(CPUStatusBarPopupView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
