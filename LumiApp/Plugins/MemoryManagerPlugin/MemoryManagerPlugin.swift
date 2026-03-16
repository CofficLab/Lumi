import MagicKit
import SwiftUI

actor MemoryManagerPlugin: SuperPlugin, SuperLog {
    
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "💾"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    
    static let id = "MemoryManager"
    static let navigationId: String? = nil
    static let displayName = String(localized: "Memory Monitor", table: "MemoryManager")
    static let description = String(localized: "Real-time monitoring of system memory usage", table: "MemoryManager")
    static let iconName = "memorychip"
    static var order: Int { 32 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = MemoryManagerPlugin()
    
    // MARK: - Lifecycle
    // 不在 init 中创建 Task，避免时序与竞态。MemoryHistoryService.shared 在首次被访问时
    // 会自行初始化并在其 init 内调用 startRecording()，由状态栏等 UI 访问时触发即可。

    // MARK: - UI
    
    @MainActor func addStatusBarPopupView() -> AnyView? {
        return AnyView(MemoryStatusBarPopupView())
    }
}
