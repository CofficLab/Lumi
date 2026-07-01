import Foundation
import SuperLogKit
import os

/// 项目列表内存存储实现，供插件通过 `LumiPluginDependencies.resolve(LumiProjectStoring.self)` 获取。
public final class LumiProjectStore: LumiProjectStoring, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose = false
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.project-store")
    
    /// 当前项目列表
    public private(set) var projects: [LumiProjectEntry] = []
    
    /// 当前选中的项目
    public var currentProject: LumiProjectEntry? {
        projects.first { $0.path == currentProjectPath }
    }
    
    private let currentProjectPathStore: LumiCurrentProjectPathStore
    private let lock = NSLock()
    
    private var currentProjectPath: String {
        currentProjectPathStore.currentProjectPath
    }
    
    public init(currentProjectPathStore: LumiCurrentProjectPathStore) {
        self.currentProjectPathStore = currentProjectPathStore
    }
    
    public func select(_ project: LumiProjectEntry) {
        lock.lock()
        defer { lock.unlock() }
        guard projects.contains(where: { $0.path == project.path }) else { return }
        currentProjectPathStore.setCurrentProjectPath(project.path, reason: "用户选中项目")
    }
    
    public func setCurrentProjectPath(_ path: String, reason: String) {
        currentProjectPathStore.setCurrentProjectPath(path, reason: reason)
    }
    
    @discardableResult
    public func add(path: String, select shouldSelect: Bool = false) throws -> LumiProjectEntry {
        lock.lock()
        defer { lock.unlock() }
        
        // 检查是否已存在
        if let existingIndex = projects.firstIndex(where: { $0.path == path }) {
            // 更新时间戳并移到最前
            let existing = projects[existingIndex]
            let updated = LumiProjectEntry(
                name: existing.name,
                path: path,
                lastUsed: Date()
            )
            projects.remove(at: existingIndex)
            projects.insert(updated, at: 0)
            
            if shouldSelect {
                select(updated)
            }
            
            if Self.verbose {
                Self.logger.info("\(Self.t)更新项目: \(path)")
            }
            
            return updated
        }
        
        // 创建新项目
        let name = URL(fileURLWithPath: path).lastPathComponent
        let entry = LumiProjectEntry(name: name, path: path, lastUsed: Date())
        projects.insert(entry, at: 0)
        
        if shouldSelect {
            select(entry)
        }
        
        if Self.verbose {
            Self.logger.info("\(Self.t)添加项目: \(path)")
        }
        
        return entry
    }
    
    public func remove(_ project: LumiProjectEntry) {
        lock.lock()
        defer { lock.unlock() }
        
        projects.removeAll { $0.path == project.path }
        
        // 如果删除的是当前项目，清除选中状态
        if currentProjectPath == project.path {
            currentProjectPathStore.setCurrentProjectPath("", reason: "项目已删除")
        }
        
        if Self.verbose {
            Self.logger.info("\(Self.t)删除项目: \(project.path)")
        }
    }
}
