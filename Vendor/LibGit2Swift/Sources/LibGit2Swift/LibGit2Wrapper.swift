import Clibgit2
import Foundation
import MagicLog
import OSLog

/// libgit2 C 库的 Swift 封装
/// 提供类型安全的接口和自动内存管理
/// libgit2 C 库的 Swift 封装
/// 提供类型安全的接口和自动内存管理
public class LibGit2: SuperLog {
    public static let emoji = "🗂️"

    // MARK: - 访问串行化

    /// 所有 libgit2 C 层调用经由的仓库级执行队列池。
    ///
    /// libgit2 即便以 GIT_THREADS 构建，也只保证"不同对象可在不同线程使用"，
    /// 对同一仓库的并发操作存在已知竞态，曾导致宿主 App 因内存破坏随机崩溃
    /// （EXC_BREAKPOINT / pthread_self PAC 校验失败，破坏数据中出现 libgit2 全局
    /// 符号）。因此库内部强制：任何线程进入公开 API 都必须经由执行队列串行执行。
    ///
    /// 串行粒度是**单个仓库**而非整个进程：同一仓库串行以保证竞态安全，
    /// 不同仓库并行以避免慢仓库阻塞其他仓库的 Git 操作。
    private static let queuePool = LibGit2QueuePool.shared

    /// 首次进入任何 API 前确保 C 层完成初始化（恰好一次）。
    ///
    /// 若从未调用 `git_libgit2_init()`，`errors.c` 的 `_tls_key` 保持为 0，
    /// libgit2 错误处理路径会把 TSD 0 号槽（macOS 保留给 PAC 签名的
    /// `pthread_self` 值）当作自己的 TLS 存储读写，导致宿主进程随机
    /// `EXC_BREAKPOINT`（`pthread_self` PAC 校验失败，`brk #0xc473`，
    /// 崩溃现场 TSD 槽内为 `&git_str__oom`）。该 bug 曾在生产环境多次出现，
    /// 仅发生在从未显式调用 `initialize()` 的宿主 App 中。
    ///
    /// `static let` 的惰性初始化自带 dispatch_once 语义，线程安全。
    /// 与 `initialize()` 的引用计数相互独立：这里多出来的一次 C 层 init
    /// 永不 shutdown，保证 C 层在进程生命周期内始终可用。
    private static let cLayerInitialized: Void = {
        git_libgit2_init()
    }()

    /// 在**指定仓库**的执行队列上执行 `body`。
    ///
    /// 同一仓库串行执行以保证 libgit2 竞态安全；不同仓库并行执行，避免慢仓库
    /// 阻塞其他仓库的 Git 操作。库内部公开方法之间互相调用（如 `pull` 调用
    /// `hasUncommittedChanges`）会命中队列池的重入检测，直接执行而不会死锁。
    ///
    /// - Parameter repositoryPath: 操作目标仓库路径。这是**必须**显式提供的：
    ///   省略会使并发保护退化为进程级，正是需要消除的行为。
    static func serialized<T>(at repositoryPath: String, _ body: () throws -> T) rethrows -> T {
        _ = cLayerInitialized
        return try queuePool.sync(repositoryPath: repositoryPath, body)
    }

    /// 在指定仓库的执行队列上运行可取消的操作。
    static func serialized<T>(
        at repositoryPath: String,
        cancellation: GitCancellationToken,
        _ body: @escaping () throws -> T
    ) throws -> T {
        _ = cLayerInitialized
        return try queuePool.sync(
            repositoryPath: repositoryPath,
            cancellation: cancellation,
            body
        )
    }

    /// 在**全局执行队列**上执行 `body`，用于无单一仓库语义的操作。
    ///
    /// 仅限生命周期（`initialize` / `shutdown`）、版本查询、全局配置与纯工具
    /// 函数（如 `oidToString`）使用。任何以单个仓库为目标的操作都必须改用
    /// `serialized(at:)`，否则会重新引入"一个慢仓库阻塞全部仓库"的问题。
    static func serialized<T>(_ body: () throws -> T) rethrows -> T {
        _ = cLayerInitialized
        return try queuePool.sync(repositoryPath: nil, body)
    }


    /// 内部状态：libgit2 引用计数 + 保护锁
    ///
    /// libgit2 要求 `git_libgit2_init()` / `git_libgit2_shutdown()` 成对调用，
    /// 多次 init 必须匹配相同次数的 shutdown。这里用引用计数 + OSAllocatedUnfairLock
    /// 保证幂等与线程安全：第一次 init 时调用 C 层 init，后续 init 只递增计数；
    /// shutdown 把计数减到 0 时才真正调 C 层 shutdown。
    private struct State {
        var refCount: Int = 0
    }

    private static let initLock = OSAllocatedUnfairLock<State>(initialState: State())

    /// 当前已初始化次数（仅供诊断/测试用）
    public static var initializationCount: Int {
        initLock.withLock { $0.refCount }
    }

    /// 初始化 libgit2（应用启动时调用一次）。
    ///
    /// 幂等且线程安全：可从任意线程、任意时机重复调用；内部用引用计数保证
    /// `git_libgit2_init()` 只在首次调用时真正触发 C 层。
    public static func initialize() {
        LibGit2.serialized {
            let shouldCallC = initLock.withLock { state -> Bool in
                state.refCount += 1
                return state.refCount == 1
            }

            if shouldCallC {
                git_libgit2_init()
                // 注意：git_libgit2_opts 是可变参数函数，在 Swift 中不可直接调用
                // 大多数情况下 libgit2 会自动找到正确的 HOME 目录
                // 如果需要设置 HOMEDIR，可以通过环境变量实现
            }
        }
    }

    /// 清理 libgit2（应用退出时调用）。
    ///
    /// 幂等且线程安全：必须与 `initialize()` 的调用次数配对；只有最后一次
    /// shutdown（即计数从 1 减到 0）才真正调用 C 层 shutdown。
    public static func shutdown() {
        LibGit2.serialized {
            let shouldCallC = initLock.withLock { state -> Bool in
                state.refCount = max(0, state.refCount - 1)
                return state.refCount == 0
            }

            if shouldCallC {
                git_libgit2_shutdown()
            }
        }
    }

    /// 当前链接的 libgit2 版本。
    public static func versionString() -> String {
        return LibGit2.serialized {
            var major: Int32 = 0
            var minor: Int32 = 0
            var revision: Int32 = 0
            git_libgit2_version(&major, &minor, &revision)
            return "\(major).\(minor).\(revision)"
        }
    }

    /// 获取 libgit2 最后一次发生的错误描述
    private static func lastError() -> String {
        if let error = git_error_last() {
            return String(cString: error.pointee.message)
        }
        return "No specific libgit2 error message"
    }

    /// 从指定仓库路径获取配置值
    /// - Parameters:
    ///   - key: 配置键（如 "user.name"）
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: 配置值
    public static func getConfig(key: String, at repoPath: String, verbose: Bool) throws -> String {
        return try LibGit2.serialized(at: repoPath) {
            if verbose { os_log("\(t)Getting config for key: \(key) at path: \(repoPath)") }

            var repo: OpaquePointer?
            var config: OpaquePointer?
            var localConfig: OpaquePointer?
            var snapshot: OpaquePointer?
            var outPtr: UnsafePointer<CChar>?

            defer {
                if snapshot != nil { git_config_free(snapshot) }
                if localConfig != nil { git_config_free(localConfig) }
                if config != nil { git_config_free(config) }
                if repo != nil { git_repository_free(repo) }
            }

            let openResult = git_repository_open(&repo, repoPath)
            if openResult == 0, let repository = repo {
                if git_repository_config(&config, repository) == 0, let configuration = config {
                    guard git_config_open_level(&localConfig, configuration, GIT_CONFIG_LEVEL_LOCAL) == 0,
                          let localConfiguration = localConfig else {
                        throw LibGit2Error.configKeyNotFound(key)
                    }

                    // 在 libgit2 1.x 中，获取字符串必须在 snapshot 上操作
                    if git_config_snapshot(&snapshot, localConfiguration) == 0, let configSnapshot = snapshot {
                        let getResult = git_config_get_string(&outPtr, configSnapshot, key)
                        if getResult == 0, let cString = outPtr {
                            let value = String(cString: cString)
                            if verbose { os_log("\(LibGit2.t)Config found in repo: \(key) = \(value)") }
                            return value
                        }
                        if verbose { os_log("\(LibGit2.t)Key not found in repo snapshot, code: \(getResult)") }
                    }
                }
            } else {
                if verbose { os_log("\(LibGit2.t)Could not open repo at \(repoPath)") }
                throw LibGit2Error.repositoryNotFound(repoPath)
            }

            throw LibGit2Error.configKeyNotFound(key)
        }
    }

    /// 设置配置值
    /// - Parameters:
    ///   - key: 配置键（如 "user.name"）
    ///   - value: 配置值
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func setConfig(key: String, value: String, at repoPath: String, verbose: Bool) throws {
        try LibGit2.serialized(at: repoPath) {
            if verbose { os_log("\(LibGit2.t)Setting config for key: \(key) at path: \(repoPath)") }

            let repo = try openRepository(at: repoPath)
            defer { git_repository_free(repo) }

            var config: OpaquePointer?
            defer { if config != nil { git_config_free(config) } }

            guard git_repository_config(&config, repo) == 0,
                  let configuration = config else {
                throw LibGit2Error.configNotFound
            }

            let result: Int32
            if value.isEmpty {
                // 空值表示删除配置
                result = git_config_delete_entry(configuration, key)
                // 删除不存在的配置不应该抛出错误
                if result != 0 && result != GIT_ENOTFOUND.rawValue {
                    throw LibGit2Error.configKeyNotFound(key)
                }
            } else {
                result = git_config_set_string(configuration, key, value)
                if result != 0 {
                    throw LibGit2Error.configKeyNotFound(key)
                }
            }

            if verbose { os_log("\(LibGit2.t)Config set successfully: \(key) = \(value)") }
        }
    }

    /// 获取用户配置（用户名和邮箱）
    /// - Parameters:
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: (用户名, 邮箱)元组
    public static func getUserConfig(at repoPath: String, verbose: Bool) throws -> (name: String, email: String) {
        return try LibGit2.serialized(at: repoPath) {
            let name = try getConfig(key: "user.name", at: repoPath, verbose: verbose)
            let email = try getConfig(key: "user.email", at: repoPath, verbose: verbose)
            return (name, email)
        }
    }

    static func createSignature(at repoPath: String, verbose: Bool) throws -> UnsafeMutablePointer<git_signature> {
        let userConfig = try? getUserConfig(at: repoPath, verbose: verbose)
        let name = userConfig?.name ?? "GitOK User"
        let email = userConfig?.email ?? "gitok@example.com"

        var signature: UnsafeMutablePointer<git_signature>?
        if git_signature_now(&signature, name, email) != 0 || signature == nil {
            if verbose { os_log("\(LibGit2.t)Failed to create configured signature, using defaults") }
            git_signature_now(&signature, "GitOK User", "gitok@example.com")
        }

        guard let signature else {
            throw LibGit2Error.commitFailed
        }

        return signature
    }

    /// 设置用户配置
    /// - Parameters:
    ///   - name: 用户名
    ///   - email: 用户邮箱
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func setUserConfig(name: String, email: String, at repoPath: String, verbose: Bool) throws {
        try LibGit2.serialized(at: repoPath) {
            try setConfig(key: "user.name", value: name, at: repoPath, verbose: verbose)
            try setConfig(key: "user.email", value: email, at: repoPath, verbose: verbose)
        }
    }

    /// 获取用户名
    /// - Parameters:
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志
    /// - Returns: 用户名
    public static func getUserName(at repoPath: String, verbose: Bool) throws -> String {
        return try LibGit2.serialized(at: repoPath) {
            return try getConfig(key: "user.name", at: repoPath, verbose: verbose)
        }
    }

    /// 获取用户邮箱
    /// - Parameters:
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    /// - Returns: 用户邮箱
    public static func getUserEmail(at repoPath: String, verbose: Bool = true) throws -> String {
        return try LibGit2.serialized(at: repoPath) {
            return try getConfig(key: "user.email", at: repoPath, verbose: verbose)
        }
    }

    /// 设置用户名
    /// - Parameters:
    ///   - name: 用户名
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func setUserName(name: String, at repoPath: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: repoPath) {
            try setConfig(key: "user.name", value: name, at: repoPath, verbose: verbose)
        }
    }

    /// 设置用户邮箱
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - repoPath: 仓库路径
    ///   - verbose: 是否输出详细日志，默认为true
    public static func setUserEmail(email: String, at repoPath: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: repoPath) {
            try setConfig(key: "user.email", value: email, at: repoPath, verbose: verbose)
        }
    }

    // MARK: - 辅助函数

    /// 将 git_oid 转换为字符串
    public static func oidToString(_ oid: git_oid) -> String {
        return LibGit2.serialized {
            var mutableOid = oid
            var buffer = [Int8](repeating: 0, count: Int(GIT_OID_HEXSZ) + 1)
            git_oid_tostr(&buffer, Int(GIT_OID_HEXSZ) + 1, &mutableOid)
            return String(cString: &buffer)
        }
    }

    /// 打开仓库
    public static func openRepository(at path: String) throws -> OpaquePointer {
        return try LibGit2.serialized(at: path) {
            var repo: OpaquePointer?
            let result = git_repository_open(&repo, path)

            if result != 0 {
                throw LibGit2Error.repositoryNotFound(path)
            }

            guard let repository = repo else {
                throw LibGit2Error.invalidRepository
            }

            return repository
        }
    }
}

/// libgit2 错误类型
public enum LibGit2Error: Error, LocalizedError {
    // 现有错误
    case repositoryNotFound(String)
    case configNotFound
    case configKeyNotFound(String)
    case invalidValue
    case cannotGetIndex
    case cannotWriteTree
    case cannotGetHEAD
    case cannotCreateRevwalk
    case cannotGetStatus
    case nothingToCommit
    case commitFailed
    case addFileFailed(String)
    case checkoutFailed(String)
    case remoteNotFound(String)
    case pushFailed(String) // 修改：携带详细错误消息
    case pullFailed(String) // 修改：携带详细错误消息
    case cloneFailed(message: String?)
    case mergeConflict
    case invalidRepository
    case invalidReference
    case networkError(Int)
    case authenticationError
    case localChangesWouldBeOverwritten(message: String)
    /// 当前仓库未设置 upstream（`branch.<name>.remote` / `branch.<name>.merge`）。
    case noUpstreamConfigured(branch: String)
    /// upstream 指向的远程引用在本地不存在（通常因为尚未 fetch）。
    case upstreamReferenceNotFound(String)
    /// 操作前提不满足（例如仓库正处于 merge / rebase 中途）。
    case invalidRepositoryState(String)

    public var errorDescription: String? {
        switch self {
        case let .repositoryNotFound(path):
            return "Git repository not found at: \(path)"
        case .configNotFound:
            return "Failed to get git configuration"
        case let .configKeyNotFound(key):
            return "Configuration key not found: \(key)"
        case .invalidValue:
            return "Invalid configuration value"
        case .cannotGetHEAD:
            return "Cannot get HEAD reference"
        case .cannotGetIndex:
            return "Cannot get repository index"
        case .cannotCreateRevwalk:
            return "Cannot create revision walker"
        case .cannotGetStatus:
            return "Cannot get repository status"
        case .cannotWriteTree:
            return "Cannot write tree object"
        case .nothingToCommit:
            return "Nothing to commit"
        case .commitFailed:
            return "Failed to create commit"
        case let .addFileFailed(file):
            return "Failed to add file: \(file)"
        case let .checkoutFailed(branch):
            return "Failed to checkout branch: \(branch)"
        case let .remoteNotFound(remote):
            return "Remote not found: \(remote)"
        case let .pushFailed(message):
            return message // 修改：使用详细错误消息
        case let .pullFailed(message):
            return message // 修改：使用详细错误消息
        case let .cloneFailed(message):
            return message ?? "Failed to clone repository"
        case .mergeConflict:
            return "Merge conflict detected"
        case .invalidRepository:
            return "Invalid repository"
        case .invalidReference:
            return "Invalid reference"
        case let .networkError(code):
            return "Network error occurred: \(code)"
        case .authenticationError:
            return "Authentication failed"
        case let .localChangesWouldBeOverwritten(message):
            return message
        case let .noUpstreamConfigured(branch):
            return "Branch '\(branch)' has no upstream configured."
        case let .upstreamReferenceNotFound(reference):
            return "Upstream reference not found: \(reference). Try fetching first."
        case let .invalidRepositoryState(message):
            return message
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .authenticationError:
            return "Please check your credentials and try again"
        case .networkError:
            return "Please check your network connection"
        case .mergeConflict:
            return "Please resolve conflicts before continuing"
        case .localChangesWouldBeOverwritten:
            return "Commit or stash your changes before continuing"
        case .noUpstreamConfigured:
            return "Publish the branch or set an upstream before pushing or pulling"
        default:
            return nil
        }
    }
}
