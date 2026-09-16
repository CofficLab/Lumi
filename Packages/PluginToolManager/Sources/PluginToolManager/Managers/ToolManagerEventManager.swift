import Foundation
import KitSuperLog
import os
import ProviderToolManager

/// 负责管理 ToolManager 的事件监听与分发。
///
/// 事件管理独立于工具注册、执行和记录存储，避免 ToolManager 同时承担
/// 事件订阅生命周期与业务执行职责。
@MainActor
final class ToolManagerEventManager: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.tool-manager",
        category: "ToolManagerEventManager"
    )
    public nonisolated static let emoji = "📣"
    nonisolated static let verbose = true

    private var observers: [UUID: (ToolManagerEvent) -> Void] = [:]

    @discardableResult
    func addObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ToolManagerServiceObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func send(_ event: ToolManagerEvent) {
        for callback in observers.values {
            callback(event)
        }
    }

    private func eventName(_ event: ToolManagerEvent) -> String {
        switch event {
        case .toolsChanged: return "toolsChanged"
        case .started: return "started"
        case .authorizationRequired: return "authorizationRequired"
        case .completed: return "completed"
        case .authorizedCompleted: return "authorizedCompleted"
        case .batchCompleted: return "batchCompleted"
        }
    }
}
