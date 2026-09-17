import Foundation
import KitAgentTool
import KitMCP
import Combine

/// MCP 服务器注册表：配置持久化 + CRUD + 单工具风险覆盖 + 全局设置。
///
/// 存储约定与现有插件一致：`UserDefaults` + JSON 编码（`MCPServerConfig` 与
/// `CommandRiskLevel` 均 `Codable`）。主线程隔离（UI 直接观察）。
@MainActor
public final class MCPServerRegistry: ObservableObject {
    // MARK: - Published State

    /// 全部已配置服务器（含禁用项）。
    @Published public private(set) var servers: [MCPServerConfig] = []
    /// MCP 总开关。关闭时全部服务器不连接、不注册工具。
    @Published public var globalEnabled: Bool = true
    /// 未知工具（不在任何分级规则中）的默认风险等级。默认 `high`。
    @Published public var unknownToolDefaultLevel: CommandRiskLevel = .high

    // MARK: - Storage

    private let defaults: UserDefaults
    private let lock = NSLock()

    private enum Keys {
        static let servers = "PluginMCP.servers"
        static let riskOverrides = "PluginMCP.toolRiskOverrides"
        static let globalEnabled = "PluginMCP.globalEnabled"
        static let unknownDefault = "PluginMCP.unknownDefault"
        static let hasSeededPresets = "PluginMCP.hasSeededPresets"
    }

    // MARK: - Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        seedPresetsIfNeeded()
    }

    private func load() {
        globalEnabled = defaults.object(forKey: Keys.globalEnabled) as? Bool ?? true
        if let raw = defaults.string(forKey: Keys.unknownDefault),
           let level = CommandRiskLevel(rawValue: raw) {
            unknownToolDefaultLevel = level
        }
        servers = decodeServers(defaults.data(forKey: Keys.servers))
    }

    private func seedPresetsIfNeeded() {
        guard !defaults.bool(forKey: Keys.hasSeededPresets) else { return }
        // 首次运行：落库 Xcode (native) 内置预设（禁用态，用户显式启用）。
        var preset = MCPServerTemplate.xcodeNative
        preset.enabled = false
        servers.append(preset)
        defaults.set(true, forKey: Keys.hasSeededPresets)
        persist()
    }

    // MARK: - Server CRUD

    /// 新增服务器（自动生成 id）。
    @discardableResult
    public func addServer(_ config: MCPServerConfig) -> MCPServerConfig {
        var resolved = config
        if resolved.id.isEmpty {
            resolved.id = UUID().uuidString
        }
        servers.append(resolved)
        persist()
        return resolved
    }

    /// 更新服务器（按 id 匹配；不存在则新增）。
    public func updateServer(_ config: MCPServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else {
            addServer(config)
            return
        }
        servers[index] = config
        persist()
    }

    /// 按 id 移除服务器（同时清理该服务器的风险覆盖）。
    public func removeServer(id: String) {
        servers.removeAll { $0.id == id }
        var overrides = decodeOverrides(defaults.data(forKey: Keys.riskOverrides))
        overrides.removeValue(forKey: id)
        setOverrides(overrides)
        persist()
    }

    public func server(id: String) -> MCPServerConfig? {
        servers.first { $0.id == id }
    }

    // MARK: - Per-Tool Risk Overrides

    /// 用户为某台服务器的某个工具指定的风险等级覆盖。
    public func riskOverride(serverID: String, toolName: String) -> CommandRiskLevel? {
        decodeOverrides(defaults.data(forKey: Keys.riskOverrides))[serverID]?[toolName]
    }

    /// 设置（或清除）单工具风险覆盖。`nil` 表示回到策略自动判定。
    public func setRiskOverride(serverID: String, toolName: String, level: CommandRiskLevel?) {
        var overrides = decodeOverrides(defaults.data(forKey: Keys.riskOverrides))
        if let level {
            overrides[serverID, default: [:]][toolName] = level
        } else {
            overrides[serverID]?[toolName] = nil
            if overrides[serverID]?.isEmpty == true { overrides[serverID] = nil }
        }
        setOverrides(overrides)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(globalEnabled, forKey: Keys.globalEnabled)
        defaults.set(unknownToolDefaultLevel.rawValue, forKey: Keys.unknownDefault)
        if let data = try? JSONEncoder().encode(servers) {
            defaults.set(data, forKey: Keys.servers)
        }
        // riskOverrides 已在 setOverrides 中写入
    }

    private func setOverrides(_ overrides: [String: [String: CommandRiskLevel]]) {
        if let data = try? JSONEncoder().encode(overrides) {
            defaults.set(data, forKey: Keys.riskOverrides)
        }
    }

    private func decodeServers(_ data: Data?) -> [MCPServerConfig] {
        guard let data, let decoded = try? JSONDecoder().decode([MCPServerConfig].self, from: data) else {
            return []
        }
        return decoded
    }

    private func decodeOverrides(_ data: Data?) -> [String: [String: CommandRiskLevel]] {
        guard let data, let decoded = try? JSONDecoder().decode([String: [String: CommandRiskLevel]].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

/// `MCPServerConfig.id` 即唯一标识，供 SwiftUI `ForEach` / `sheet(item:)` 使用。
extension MCPServerConfig: Identifiable {}
