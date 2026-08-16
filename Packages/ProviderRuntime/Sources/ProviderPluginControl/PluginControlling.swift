import Foundation
@MainActor public protocol PluginControlling: AnyObject { func enablePlugin(id: String) async -> Bool; func disablePlugin(id: String) async -> Bool; func isEnabled(id: String) -> Bool }
@MainActor public final class DefaultPluginControlling: PluginControlling { private var enabled: Set<String> = []; public init() {}; public func enablePlugin(id: String) async -> Bool { enabled.insert(id); return true }; public func disablePlugin(id: String) async -> Bool { enabled.remove(id); return true }; public func isEnabled(id: String) -> Bool { enabled.contains(id) } }
