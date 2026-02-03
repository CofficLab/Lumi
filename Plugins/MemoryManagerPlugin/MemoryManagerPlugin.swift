import SwiftUI
import MagicKit

actor MemoryManagerPlugin: SuperPlugin, SuperLog {
    
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "💾"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "MemoryManager"
    static let displayName = "内存监控"
    static let description = "实时监控系统内存使用情况"
    static let iconName = "memorychip"
    static var order: Int { 32 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = MemoryManagerPlugin()
    
    // MARK: - Lifecycle
    
    init() {
        Task { @MainActor in
            MemoryHistoryService.shared.startRecording()
        }
    }
    
    // MARK: - UI
    
    @MainActor func addStatusBarPopupView() -> AnyView? {
        return AnyView(MemoryStatusBarPopupView())
    }
}
