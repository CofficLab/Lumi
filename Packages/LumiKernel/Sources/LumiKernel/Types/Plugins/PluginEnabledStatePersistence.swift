import Foundation

/// Plugin-owned persistence for user-configurable plugin enablement.
///
/// The kernel owns the in-memory decision cache; a plugin such as
/// `PluginManagerPlugin` owns the on-disk representation.
@MainActor
public protocol PluginEnabledStatePersistence: AnyObject {
    func loadPluginEnabledOverrides() -> [String: Bool]
    func savePluginEnabledOverride(_ enabled: Bool, for pluginID: String)
    func clearPluginEnabledOverride(for pluginID: String)
}
