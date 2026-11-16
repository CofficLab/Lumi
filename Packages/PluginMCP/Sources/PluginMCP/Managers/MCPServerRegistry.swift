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
    private let deletedTemplatesFileURL: URL
    /// 用户删除的服务器墓碑（command + arguments）；阻止内置模板重启后被重新 seed（#295）。
    private var deletedTemplates: [MCPServerConfig] = []
    /// 加载失败标记：配置文件存在但读不出/解不开时置位。
    /// 此后禁止任何 `persist()` 覆盖原文件，避免 seed/CRUD 把用户配置冲掉（#531）。
    private(set) var loadFailed = false

    // MARK: - Init

    public init(directory: URL, contributor: MCPServerContributor? = nil) {
        self.fileURL = directory.appendingPathComponent("mcp-servers.json", isDirectory: false)
        self.deletedTemplatesFileURL = directory.appendingPathComponent("mcp-deleted-templates.json", isDirectory: false)
        load()
        if let contributor {
            observeContributor(contributor)
        }
    }

    private func load() {
        deletedTemplates = (try? Data(contentsOf: deletedTemplatesFileURL))
            .flatMap { try? JSONDecoder().decode([MCPServerConfig].self, from: $0) } ?? []

        // 文件不存在 = 首次运行：内存置空，允许后续 seed 落库。
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            servers = []
            return
        }

        // 文件存在但读不出/解不开：绝不能当成「用户没配置」而清空写回，
        // 否则一次解码失败就会用 seed 模板原子覆盖掉用户的全部配置（#531）。
        // 保留原文件、置 loadFailed、内存置空，后续 persist 一律拒绝。
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([MCPServerConfig].self, from: data)
            // 数据自愈：按 id 去重。历史版本编辑服务器会追加同 id 条目，
            // 重复 id 会让 SwiftUI ForEach 渲染错乱（列表出现空白行）。去重后写回。
            let rawCount = decoded.count
            servers = deduplicated(decoded)
            // 数据自愈：历史版本的启停开关只写 enabled，留下 enabled=true/autoStart=false，
            // 重启后 startAutoStartServers 会跳过它（#533）。启用即随启动恢复。
            let needsAutoStartRepair = servers.contains { $0.enabled && !$0.autoStart }
            if needsAutoStartRepair {
                servers = servers.map { server in
                    var repaired = server
                    if repaired.enabled {
                        repaired.autoStart = true
                    }
                    return repaired
                }
            }
            if servers.count != rawCount || needsAutoStartRepair {
                persist()
            }
        } catch {
            servers = []
            loadFailed = true
            print("[MCPServerRegistry] load failed, preserving original file: \(error)")
        }
    }

    /// 按 `id` 去重，保留每条 id 首次出现的位置与内容。
    private func deduplicated(_ configs: [MCPServerConfig]) -> [MCPServerConfig] {
        var seen = Set<String>()
        return configs.filter { seen.insert($0.id).inserted }
    }

    /// 观察贡献收集器：新贡献的服务器模板以禁用态自动 seed 到本地列表。
    ///
    /// 用同步回调而非 Observation：`withObservationTracking` 对 `@Published`
    /// 属性的读取不注册访问跟踪，onChange 不会触发，导致 Registry 初始化
    /// 之后的贡献（如 PluginXcodeMCP 贡献的 Xcode）全部丢失。
    private func observeContributor(_ contributor: MCPServerContributor) {
        seedContributions(contributor.contributions)
        contributor.onContribute = { [weak self] server in
            self?.seedContributions([server])
        }
    }

    private func seedContributions(_ contributions: [MCPServerConfig]) {
        var changed = false
        for var template in contributions where !servers.contains(where: {
            $0.command == template.command && $0.arguments == template.arguments
        }) && !deletedTemplates.contains(where: {
            $0.command == template.command && $0.arguments == template.arguments
        }) {
            template.enabled = false
            servers.append(template)
            changed = true
        }
        if changed { persist() }
    }

    // MARK: - Server CRUD

    /// 新增服务器（自动生成 id）。写入失败抛出，内存列表保持不变（#532）。
    @discardableResult
    public func addServer(_ config: MCPServerConfig) throws -> MCPServerConfig {
        var resolved = config
        if resolved.id.isEmpty {
            resolved.id = UUID().uuidString
        }
        var updated = servers
        updated.append(resolved)
        try persist(updated)
        servers = updated
        return resolved
    }

    /// 更新服务器（按 id 匹配；不存在则新增）。写入失败抛出，内存列表保持不变（#532）。
    /// 同 id 的历史重复条目一并替换，保证 `id` 在列表中唯一。
    public func updateServer(_ config: MCPServerConfig) throws {
        guard let index = servers.firstIndex(where: { $0.id == config.id }) else {
            try addServer(config)
            return
        }
        var updated = servers
        updated.removeAll { $0.id == config.id }
        updated.insert(config, at: min(index, updated.count))
        try persist(updated)
        servers = updated
    }

    /// 按 id 移除服务器。写入失败抛出，内存列表与模板墓碑都保持不变（#532）。
    public func removeServer(id: String) throws {
        var updated = servers
        updated.removeAll { $0.id == id }
        try persist(updated)
        // 墓碑只在删除确实落库后记录：否则一次失败的删除会永久屏蔽该内置模板。
        if let removed = servers.first(where: { $0.id == id }) {
            recordDeletedTemplate(removed)
        }
        servers = updated
    }

    public func server(id: String) -> MCPServerConfig? {
        servers.first { $0.id == id }
    }

    // MARK: - Persistence

    /// 启动期自愈 / seed 的尽力写回：失败只记录，不阻断插件启动。
    private func persist() {
        do {
            try persist(servers)
        } catch {
            print("[MCPServerRegistry] persist failed: \(error)")
        }
    }

    /// 用户操作的写回：失败必须抛出，让 UI 保留编辑页并显示错误（#532）。
    private func persist(_ configs: [MCPServerConfig]) throws {
        // 加载失败时拒绝写回：原文件可能是用户的全部配置，
        // 不能用内存里的空列表/seed 模板原子覆盖它（#531）。
        guard !loadFailed else {
            print("[MCPServerRegistry] skip persist: load failed, refusing to overwrite original file")
            throw MCPServerRegistryError.loadFailed
        }
        do {
            let data = try JSONEncoder().encode(configs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[MCPServerRegistry] persist failed: \(error)")
            throw MCPServerRegistryError.writeFailed(underlying: error)
        }
    }

    private func recordDeletedTemplate(_ config: MCPServerConfig) {
        guard !deletedTemplates.contains(where: {
            $0.command == config.command && $0.arguments == config.arguments
        }) else { return }
        deletedTemplates.append(config)
        persistDeletedTemplates()
    }

    private func persistDeletedTemplates() {
        do {
            let data = try JSONEncoder().encode(deletedTemplates)
            try data.write(to: deletedTemplatesFileURL, options: .atomic)
        } catch {
            print("[MCPServerRegistry] persist deleted templates failed: \(error)")
        }
    }
}

/// 注册表写回失败（#532）。CRUD 必须把它抛给调用方：
/// 只打印日志会让 UI 把「没写进磁盘」当成保存成功，重启后配置消失。
public enum MCPServerRegistryError: LocalizedError {
    /// 配置文件加载失败（#531）：拒绝写回，避免覆盖用户原始配置。
    case loadFailed
    /// 编码或原子写入失败。
    case writeFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "The MCP configuration file could not be read, so saving is disabled to protect it."
        case .writeFailed(let error):
            return error.localizedDescription
        }
    }
}

/// `MCPServerConfig.id` 即唯一标识，供 SwiftUI `ForEach` / `sheet(item:)` 使用。
extension MCPServerConfig: Identifiable {}
