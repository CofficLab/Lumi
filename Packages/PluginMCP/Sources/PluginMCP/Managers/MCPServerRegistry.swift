import Foundation
import KitAgentTool
import KitMCP
import Combine

/// MCP 服务器注册表：配置持久化 + CRUD。
///
/// 持久化到插件数据目录下的 `mcp-servers.json`（与其他插件一致），
/// 不再使用 UserDefaults。主线程隔离（UI 直接观察）。
@MainActor
public final class MCPServerRegistry: ObservableObject {
    // MARK: - Published State

    /// 全部已配置服务器（含禁用项）。
    @Published public private(set) var servers: [MCPServerConfig] = []
    /// MCP 总开关（始终启用，保留属性以兼容 UI 绑定）。
    @Published public var globalEnabled: Bool = true
    /// 未知工具默认风险等级（保留兼容，UI 已移除）。
    @Published public var unknownToolDefaultLevel: CommandRiskLevel = .high

    // MARK: - Storage

    private let fileURL: URL

    // MARK: - Init

    public init(directory: URL, contributor: MCPServerContributor? = nil) {
        self.fileURL = directory.appendingPathComponent("mcp-servers.json", isDirectory: false)
        load()
        if let contributor {
            observeContributor(contributor)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MCPServerConfig].self, from: data)
        else {
            servers = []
            return
        }
        // 数据自愈：按 id 去重。历史版本编辑服务器会追加同 id 条目，
        // 重复 id 会让 SwiftUI ForEach 渲染错乱（列表出现空白行）。去重后写回。
        let rawCount = decoded.count
        servers = deduplicated(decoded)
        if servers.count != rawCount {
            persist()
        }
    }

    /// 按 `id` 去重，保留每条 id 首次出现的位置与内容。
    private func deduplicated(_ configs: [MCPServerConfig]) -> [MCPServerConfig] {
        var seen = Set<String>()
        return configs.filter { seen.insert($0.id).inserted }
    }

    /// 观察贡献收集器：新贡献的服务器模板以禁用态自动 seed 到本地列表。
    private func observeContributor(_ contributor: MCPServerContributor) {
        seedContributions(contributor.contributions)
        withObservationTracking {
            _ = contributor.contributions
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.seedContributions(contributor.contributions)
                self.observeContributor(contributor)
            }
        }
    }

    private func seedContributions(_ contributions: [MCPServerConfig]) {
        var changed = false
        for var template in contributions where !servers.contains(where: {
            $0.command == template.command && $0.arguments == template.arguments
        }) {
            template.enabled = false
            servers.append(template)
            changed = true
        }
        if changed { persist() }
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
    /// 同 id 的历史重复条目一并替换，保证 `id` 在列表中唯一。
    public func updateServer(_ config: MCPServerConfig) {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else {
            addServer(config)
            return
        }
        servers.removeAll { $0.id == config.id }
        servers.insert(config, at: index)
        persist()
    }

    /// 按 id 移除服务器。
    public func removeServer(id: String) {
        servers.removeAll { $0.id == id }
        persist()
    }

    public func server(id: String) -> MCPServerConfig? {
        servers.first { $0.id == id }
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[MCPServerRegistry] persist failed: \(error)")
        }
    }
}

/// `MCPServerConfig.id` 即唯一标识，供 SwiftUI `ForEach` / `sheet(item:)` 使用。
extension MCPServerConfig: Identifiable {}
