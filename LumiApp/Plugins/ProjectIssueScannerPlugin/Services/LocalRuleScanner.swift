import Foundation

/// 本地规则扫描器
///
/// 使用轻量级本地规则扫描项目文件，零成本、零 Token 消耗。
/// 检测内容：TODO/FIXME/HACK 注释、空 catch 块、大文件等。
struct LocalRuleScanner: Sendable {

    // MARK: - Configuration

    /// 忽略的目录名
    private let ignoredDirectories: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData",
        ".swiftpm", "Pods", ".gradle", "build",
        ".venv", "__pycache__", ".next", "dist"
    ]

    /// 触发大文件警告的行数阈值
    private let largeFileLineThreshold = 500

    // MARK: - Public API

    /// 扫描指定项目路径
    func scan(projectPath: String) async -> [ProjectIssue] {
        // TODO: 实现本地规则扫描
        // 1. 遍历项目文件（跳过 ignoredDirectories）
        // 2. 匹配 TODO/FIXME/HACK 注释
        // 3. 检测空 catch 块
        // 4. 检测超大文件
        // 5. 返回发现的问题列表
        []
    }
}
