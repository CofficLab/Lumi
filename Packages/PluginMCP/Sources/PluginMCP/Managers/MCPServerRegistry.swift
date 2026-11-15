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
            if servers.count != rawCount {
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
        if let removed = servers.first(where: { $0.id == id }) {
            recordDeletedTemplate(removed)
        }
        servers.removeAll { $0.id == id }
        persist()
    }

    public func server(id: String) -> MCPServerConfig? {
        servers.first { $0.id == id }
    }

    // MARK: - Persistence

    private func persist() {
        // 加载失败时拒绝写回：原文件可能是用户的全部配置，
        // 不能用内存里的空列表/seed 模板原子覆盖它（#531）。
        guard !loadFailed else {
            print("[MCPServerRegistry] skip persist: load failed, refusing to overwrite original file")
            return
        }
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[MCPServerRegistry] persist failed: \(error)")
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

/// `MCPServerConfig.id` 即唯一标识，供 SwiftUI `ForEach` / `sheet(item:)` 使用。
extension MCPServerConfig: Identifiable {}
