import Foundation
import OSLog

/// Git 分支监听器
///
/// 监听 .git/HEAD 文件变化，实时更新分支名称。
/// 支持多个项目路径的监听管理，提供防抖和事件去重机制。
@MainActor
final class GitBranchMonitor: ObservableObject {
    // MARK: - Types
    
    /// 分支变化回调
    typealias BranchChangeCallback = @Sendable (_ projectPath: String, _ branch: String?) -> Void
    
    /// 监听器状态
    private struct MonitorState {
        let fileDescriptor: Int32
        let dispatchSource: DispatchSourceFileSystemObject
        let lastBranch: String?
        let lastUpdateTime: Date
    }
    
    // MARK: - Properties
    
    /// 项目路径 → 监听器状态
    private var monitors: [String: MonitorState] = [:]
    
    /// 分支变化回调
    private var callbacks: [BranchChangeCallback] = []
    
    /// 防抖延迟（秒）
    private let debounceDelay: TimeInterval = 0.3
    
    /// 防抖任务
    private var debounceTasks: [String: Task<Void, Never>] = [:]
    
    /// 日志记录器
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "GitBranchMonitor")
    
    /// 是否启用详细日志
    private let verbose: Bool
    
    // MARK: - Initialization
    
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    deinit {
        // Note: deinit cannot call @MainActor methods directly
        // Cleanup is handled by stopAll() before the object is released
    }
    
    // MARK: - Public API
    
    /// 添加分支变化回调
    func onBranchChange(_ callback: @escaping BranchChangeCallback) {
        callbacks.append(callback)
    }
    
    /// 开始监听指定项目路径的分支变化
    func startMonitoring(projectPath: String) {
        // 如果已经在监听，先停止
        if monitors[projectPath] != nil {
            stopMonitoring(projectPath: projectPath)
        }
        
        let headPath = "\(projectPath)/.git/HEAD"
        let headURL = URL(fileURLWithPath: headPath)
        
        // 检查 .git/HEAD 文件是否存在
        guard FileManager.default.fileExists(atPath: headPath) else {
            if verbose {
                logger.info("⏭️ 跳过非 Git 项目: \(projectPath)")
            }
            return
        }
        
        // 打开文件描述符
        let fileDescriptor = Darwin.open(headPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.error("❌ 无法打开文件描述符: \(headPath)")
            return
        }
        
        // 创建 DispatchSource
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .global(qos: .userInitiated)
        )
        
        // 设置事件处理器
        dispatchSource.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.handleFileChange(projectPath: projectPath)
            }
        }
        
        // 设置取消处理器
        dispatchSource.setCancelHandler {
            Darwin.close(fileDescriptor)
        }
        
        // 启动监听
        dispatchSource.resume()
        
        // 获取当前分支
        let currentBranch = readCurrentBranch(projectPath: projectPath)
        
        // 保存监听器状态
        let state = MonitorState(
            fileDescriptor: fileDescriptor,
            dispatchSource: dispatchSource,
            lastBranch: currentBranch,
            lastUpdateTime: Date()
        )
        monitors[projectPath] = state
        
        if verbose {
            logger.info("🎯 开始监听项目分支变化: \(projectPath)")
            logger.info("   • HEAD 路径: \(headPath)")
            logger.info("   • 当前分支: \(currentBranch ?? "nil")")
        }
    }
    
    /// 停止监听指定项目路径
    func stopMonitoring(projectPath: String) {
        guard let state = monitors[projectPath] else {
            return
        }
        
        // 取消防抖任务
        debounceTasks[projectPath]?.cancel()
        debounceTasks.removeValue(forKey: projectPath)
        
        // 取消 DispatchSource
        state.dispatchSource.cancel()
        
        // 移除监听器
        monitors.removeValue(forKey: projectPath)
        
        if verbose {
            logger.info("⏹️ 停止监听项目分支变化: \(projectPath)")
        }
    }
    
    /// 停止所有监听
    func stopAll() {
        for (projectPath, _) in monitors {
            stopMonitoring(projectPath: projectPath)
        }
        callbacks.removeAll()
    }
    
    /// 手动刷新指定项目的分支信息
    func refreshBranch(projectPath: String) {
        guard monitors[projectPath] != nil else {
            return
        }
        
        handleFileChange(projectPath: projectPath)
    }
    
    /// 批量刷新多个项目的分支信息
    func refreshBranches(projectPaths: [String]) {
        for projectPath in projectPaths {
            refreshBranch(projectPath: projectPath)
        }
    }
    
    // MARK: - Private Methods
    
    /// 处理文件变化事件
    private func handleFileChange(projectPath: String) {
        // 取消防抖任务
        debounceTasks[projectPath]?.cancel()
        
        // 创建新的防抖任务
        debounceTasks[projectPath] = Task { [weak self] in
            guard let self = self else { return }
            
            // 等待防抖延迟
            try? await Task.sleep(nanoseconds: UInt64(self.debounceDelay * 1_000_000_000))
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            // 读取当前分支
            let newBranch = self.readCurrentBranch(projectPath: projectPath)
            
            // 获取上次分支
            let lastBranch = self.monitors[projectPath]?.lastBranch
            
            // 只有当分支真正变化时才通知
            if newBranch != lastBranch {
                // 更新监听器状态
                if let state = self.monitors[projectPath] {
                    let newState = MonitorState(
                        fileDescriptor: state.fileDescriptor,
                        dispatchSource: state.dispatchSource,
                        lastBranch: newBranch,
                        lastUpdateTime: Date()
                    )
                    self.monitors[projectPath] = newState
                }
                
                // 通知所有回调
                for callback in self.callbacks {
                    callback(projectPath, newBranch)
                }
                
                if self.verbose {
                    self.logger.info("🔄 分支变化检测: \(projectPath)")
                    self.logger.info("   • 旧分支: \(lastBranch ?? "nil")")
                    self.logger.info("   • 新分支: \(newBranch ?? "nil")")
                }
            }
        }
    }
    
    /// 读取当前分支名称
    private func readCurrentBranch(projectPath: String) -> String? {
        let headPath = "\(projectPath)/.git/HEAD"
        
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8) else {
            return nil
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 解析 HEAD 文件内容
        // 格式1: "ref: refs/heads/main" -> 分支名是 "main"
        // 格式2: "abc123..." (commit hash) -> 分离头指针状态，返回 nil 或特定标识
        if trimmedContent.hasPrefix("ref: refs/heads/") {
            let branchName = String(trimmedContent.dropFirst("ref: refs/heads/".count))
            return branchName.isEmpty ? nil : branchName
        } else if trimmedContent.count == 40 && trimmedContent.allSatisfy({ $0.isHexDigit }) {
            // 分离头指针状态，返回 nil 或可以返回 "HEAD" 或 "detached"
            return nil
        }
        
        return nil
    }
}

// MARK: - Character Extension

private extension Character {
    var isHexDigit: Bool {
        return self.isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

// MARK: - Convenience Extensions

extension GitBranchMonitor {
    /// 便捷方法：开始监听并添加回调
    func startMonitoring(projectPath: String, onBranchChange callback: @escaping BranchChangeCallback) {
        self.onBranchChange(callback)
        startMonitoring(projectPath: projectPath)
    }
    
    /// 便捷方法：开始监听多个项目
    func startMonitoring(projectPaths: [String], onBranchChange callback: @escaping BranchChangeCallback) {
        self.onBranchChange(callback)
        for projectPath in projectPaths {
            startMonitoring(projectPath: projectPath)
        }
    }
}