import Combine
import Foundation
import os
import SuperLogKit

/// Kernel event dispatcher.
///
/// 所有需要对外广播的内核事件，都通过这个对象发出。
@MainActor
public final class EventManager: ObservableObject, SuperLog {
    nonisolated public static let emoji = "📣"
    nonisolated(unsafe) public static var verbose = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "kernel.event-manager")

    public init() {}

    public func post(
        _ event: LumiKernelEvent,
        object: Any? = nil,
        userInfo: [AnyHashable: Any]? = nil
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)post event=\(event.rawValue) object=\(String(describing: object.map { type(of: $0) })) userInfoKeys=\(userInfo?.keys.map { String(describing: $0) }.sorted().joined(separator: ",") ?? "nil")")
        }
        NotificationCenter.default.post(name: event.notificationName, object: object, userInfo: userInfo)
    }

    public func postEnabledPluginsDidChange(object: Any? = nil) {
        post(.enabledPluginsDidChange, object: object)
    }

    public func postMessagesDidChange(object: Any? = nil) {
        post(.messagesDidChange, object: object)
    }

    public func postConversationsDidChange(object: Any? = nil) {
        post(.conversationsDidChange, object: object)
    }

    public func postSelectedRemoteProviderIDDidChange(providerID: String?) {
        post(.selectedRemoteProviderIDDidChange, userInfo: ["providerID": providerID as Any])
    }

    public func postSelectedLocalProviderIDDidChange(providerID: String?) {
        post(.selectedLocalProviderIDDidChange, userInfo: ["providerID": providerID as Any])
    }

    public func postSelectedModelsDidChange(selectedModels: [String: String]) {
        post(.selectedModelsDidChange, userInfo: ["selectedModels": selectedModels])
    }

    public func postRoutingModeDidChange(routingMode: LumiModelRoutingMode) {
        post(.routingModeDidChange, userInfo: ["routingMode": routingMode])
    }

    public func postProviderAvailabilityDidChange(availabilityResults: [String: LumiModelAvailabilityResult]) {
        post(.providerAvailabilityDidChange, userInfo: ["availabilityResults": availabilityResults])
    }

    public func postProviderStatusesDidChange(providerStatuses: [String: LumiLLMProviderStatus]) {
        post(.providerStatusesDidChange, userInfo: ["providerStatuses": providerStatuses])
    }
}
