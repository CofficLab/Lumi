import SwiftUI
import MagicKit

actor CPUManagerPlugin: SuperPlugin, SuperLog {
    
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🧠"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "CPUManager"
    static let displayName = String(localized: "CPU Monitor")
    static let description = String(localized: "Real-time CPU usage and load monitoring")
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
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
