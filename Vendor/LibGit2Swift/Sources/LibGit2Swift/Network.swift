import Foundation
import MagicLog
import Clibgit2
import OSLog

// MARK: - Network Operations

/// 克隆过程中 libgit2 报告的对象传输进度。
public struct LibGit2CloneProgress: Equatable, Sendable {
    public let totalObjects: Int
    public let indexedObjects: Int
    public let receivedObjects: Int
    public let totalDeltas: Int
    public let indexedDeltas: Int
    public let receivedBytes: Int

    /// 根据已接收对象数计算出的进度；远程尚未提供对象总数时为 nil。
    public var fractionCompleted: Double? {
        guard totalObjects > 0 else { return nil }
        return min(max(Double(receivedObjects) / Double(totalObjects), 0), 1)
    }

    public init(
        totalObjects: Int,
        indexedObjects: Int,
        receivedObjects: Int,
        totalDeltas: Int,
        indexedDeltas: Int,
        receivedBytes: Int
    ) {
        self.totalObjects = totalObjects
        self.indexedObjects = indexedObjects
        self.receivedObjects = receivedObjects
        self.totalDeltas = totalDeltas
        self.indexedDeltas = indexedDeltas
        self.receivedBytes = receivedBytes
    }
}

private final class CloneProgressPayload: @unchecked Sendable {
    let onProgress: (@Sendable (LibGit2CloneProgress) -> Void)?
    let cancellation: GitCancellationToken?

    init(
        onProgress: (@Sendable (LibGit2CloneProgress) -> Void)?,
        cancellation: GitCancellationToken?
    ) {
        self.onProgress = onProgress
        self.cancellation = cancellation
    }
}

/// 网络操作的 C 回调函数封装
private struct NetworkCallbacks: SuperLog {
    public static let emoji = "🌐"

    /// 控制网络操作的日志输出
    static var verbose: Bool = true

    /// Push 进度回调函数
    static let pushTransferProgress: git_push_transfer_progress = { (current: UInt32, total: UInt32, bytes: Int, payload: UnsafeMutableRawPointer?) -> Int32 in
        let verbose = payload?.assumingMemoryBound(to: Bool.self).pointee ?? true
        let percent = total > 0 ? Float(current) / Float(total) * 100 : 0
        if verbose {
            os_log("\(Self.t)Push progress: \(String(format: "%.1f", percent))%")
        }
        return 0
    }

    /// Fetch/Clone 进度回调函数
    static let transferProgress: @convention(c) (UnsafePointer<git_indexer_progress>?, UnsafeMutableRawPointer?) -> Int32 = { (progress, payload) in
        guard let progress = progress else { return 0 }
        let received = progress.pointee.received_objects
        let total = progress.pointee.total_objects
        let percent = total > 0 ? Float(received) / Float(total) * 100 : 0
        let verbose = payload?.assumingMemoryBound(to: Bool.self).pointee ?? true
        if verbose {
            os_log("\(Self.t) Transfer progress: \(String(format: "%.1f", percent))%")
        }
        return 0
    }

    /// 只用于 clone 的进度回调。fetch/pull 仍使用上面的 Bool payload，避免改变已有 ABI 约定。
    static let cloneTransferProgress: @convention(c) (UnsafePointer<git_indexer_progress>?, UnsafeMutableRawPointer?) -> Int32 = { progress, payload in
        guard let progress, let payload else { return 0 }

        let progressPayload = Unmanaged<CloneProgressPayload>.fromOpaque(payload).takeUnretainedValue()
        let value = progress.pointee
        progressPayload.onProgress?(
            LibGit2CloneProgress(
                totalObjects: Int(value.total_objects),
                indexedObjects: Int(value.indexed_objects),
                receivedObjects: Int(value.received_objects),
                totalDeltas: Int(value.total_deltas),
                indexedDeltas: Int(value.indexed_deltas),
                receivedBytes: Int(value.received_bytes)
            )
        )

        return progressPayload.cancellation?.isCancelled == true ? -1 : 0
    }
}

/// LibGit2 网络操作扩展（push, pull, clone）
extension LibGit2 {
    // MARK: - Authentication Error Detection

    /// 检查错误是否是认证错误
    /// - Parameters:
    ///   - errorCode: libgit2 错误代码
    ///   - errorMessage: 错误消息
    /// - Returns: 如果是认证错误返回 true
    private static func isAuthenticationError(_ errorCode: Int32, errorMessage: String) -> Bool {
        // 检查错误代码是否是 GIT_EUSER (-3) 或其他认证相关错误
        if errorCode == Int32(GIT_EUSER.rawValue) {
            return true
        }

        // 检查错误消息中是否包含认证相关的关键词
        let lowercasedMessage = errorMessage.lowercased()
        let authKeywords = [
            "authentication",
            "auth",
            "credential",
            "permission",
            "denied",
            "unauthorized",
            "401",
            "403",
            "forbidden"
        ]

        return authKeywords.contains { lowercasedMessage.contains($0) }
    }

    /// 检查错误是否是网络/SSL 错误
    /// - Parameters:
    ///   - errorCode: libgit2 错误代码
    ///   - errorMessage: 错误消息
    /// - Returns: 如果是网络/SSL 错误返回 true
    static func isNetworkError(_ errorCode: Int32, errorMessage: String) -> Bool {
        let lowercasedMessage = errorMessage.lowercased()
        let networkKeywords = [
            // SSL/TLS 错误
            "securetransport",
            "ssl",
            "tls",
            "certificate",
            "cert",
            "-9806",    // macOS SecureTransport SSL 常见错误码
            "-9814",    // macOS SecureTransport SSL 常见错误码
            "-9802",    // macOS SecureTransport SSL 常见错误码
            "-9843",    // macOS SecureTransport SSL 常见错误码

            // 网络连接错误
            "could not resolve host",
            "failed to connect",
            "connection timed out",
            "connection refused",
            "network is unreachable",
            "no route to host",
            "operation timed out",
            "connection reset",
            "broken pipe",
            "couldn't connect",
            "couldn't resolve",
            "name resolution",
            "dns",

            // 代理错误
            "proxy",
            "tunnel",

            // curl/传输层错误
            "curl",
            "transfer",
            "socket",
        ]

        return networkKeywords.contains { lowercasedMessage.contains($0) }
    }

    // MARK: - SSH Config URL Normalization

    /// 依据 ~/.ssh/config 重写远程 URL，使 libssh2 使用正确的端口 / 主机 / 用户。
    ///
    /// libgit2 的 SSH 传输基于 libssh2，不会读取 ~/.ssh/config。当 SSH 服务
    /// 位于非 22 端口（例如 `Port 2014`）时，必须把 scp 风格 URL 显式改写为
    /// `ssh://user@host:port/path`，否则会连接被防火墙静默丢弃的 22 端口，
    /// 表现为 `failed to start SSH session: Failed getting banner`。
    ///
    /// 改写通过临时更新 git config 中的远程 URL 并重新加载远程对象实现；
    /// 返回的闭包负责把 URL 还原。所有网络操作都在仓库级串行队列内执行，
    /// 因此不会与其他操作竞争同一份配置。
    ///
    /// - Returns: 恢复闭包；无需改写时返回 nil。
    private static func rewriteRemoteURLForSSHConfig(
        repo: OpaquePointer,
        remoteName: String,
        remote: inout OpaquePointer?
    ) -> (() -> Void)? {
        guard let urlPointer = git_remote_url(remote) else { return nil }
        let originalURL = String(cString: urlPointer)
        guard let normalizedURL = SSHConfig.normalizedURL(for: originalURL),
              normalizedURL != originalURL else {
            return nil
        }

        let setNameResult = remoteName.withCString { namePointer in
            normalizedURL.withCString { urlPointer in
                git_remote_set_url(repo, namePointer, urlPointer)
            }
        }
        guard setNameResult == 0 else { return nil }

        // 释放旧远程对象并按新 URL 重新加载
        git_remote_free(remote)
        remote = nil
        guard git_remote_lookup(&remote, repo, remoteName) == 0, remote != nil else {
            // 改写失败则回滚配置并恢复原远程对象
            _ = remoteName.withCString { namePointer in
                originalURL.withCString { urlPointer in
                    git_remote_set_url(repo, namePointer, urlPointer)
                }
            }
            git_remote_free(remote)
            remote = nil
            _ = git_remote_lookup(&remote, repo, remoteName)
            return nil
        }

        if NetworkCallbacks.verbose {
            os_log("\(t)SSH config: rewrote remote URL \(originalURL, privacy: .public) -> \(normalizedURL, privacy: .public)")
        }

        return {
            _ = remoteName.withCString { namePointer in
                originalURL.withCString { urlPointer in
                    git_remote_set_url(repo, namePointer, urlPointer)
                }
            }
        }
    }

    // MARK: - Public Methods

    /// 推送到远程仓库
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - remote: 远程仓库名称（默认 "origin"）
    ///   - branch: 分支名称（nil 表示使用当前分支）
    /// 推送当前分支到其 upstream。
    ///
    /// 依据 `branch.<name>.remote` / `branch.<name>.merge` 决定推送目标，
    /// 而非假定远程分支名与本地分支名相同。未设置 upstream 时抛出
    /// `noUpstreamConfigured`，与 `git push` 在无 upstream 时的行为一致
    /// （提示用户先 publish 或设置 upstream）。
    ///
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - verbose: 是否输出详细日志
    public static func push(at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            guard let binding = try upstreamBinding(at: path) else {
                let branch = (try? currentBranchName(at: path)) ?? "HEAD"
                throw LibGit2Error.noUpstreamConfigured(branch: branch)
            }
            // 推送到 upstream 指向的远程分支：
            //   refs/heads/<local> -> refs/heads/<remoteBranch>
            try pushRefspecs([binding.pushRefspec], at: path, remote: binding.remote, verbose: verbose)
        }
    }

    /// 推送指定本地分支到指定远程的指定分支（显式指定，不读 upstream）。
    public static func push(
        localBranch: String,
        to remote: String,
        remoteBranch: String,
        at path: String,
        verbose: Bool = true
    ) throws {
        try LibGit2.serialized(at: path) {
            let local = localBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            let remoteName = remote.trimmingCharacters(in: .whitespacesAndNewlines)
            let destination = remoteBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !local.isEmpty, !remoteName.isEmpty, !destination.isEmpty else {
                throw LibGit2Error.invalidReference
            }
            let refspec = "refs/heads/\(local):refs/heads/\(destination)"
            try pushRefspecs([refspec], at: path, remote: remoteName, verbose: verbose)
        }
    }

    /// 推送本地分支到远程分支，并可选择写入 upstream 配置。
    public static func publishBranch(
        localBranch: String,
        remote: String = "origin",
        remoteBranch: String? = nil,
        at path: String,
        setUpstream: Bool = true,
        verbose: Bool = true
    ) throws {
        try LibGit2.serialized(at: path) {
            let trimmedLocalBranch = localBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRemoteBranch = remoteBranch?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedLocalBranch.isEmpty == false, trimmedRemote.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let destinationBranch = (trimmedRemoteBranch?.isEmpty == false ? trimmedRemoteBranch : nil) ?? trimmedLocalBranch
            let refspec = "refs/heads/\(trimmedLocalBranch):refs/heads/\(destinationBranch)"
            try pushRefspecs([refspec], at: path, remote: trimmedRemote, verbose: verbose)

            if setUpstream {
                try setConfig(key: "branch.\(trimmedLocalBranch).remote", value: trimmedRemote, at: path, verbose: false)
                try setConfig(key: "branch.\(trimmedLocalBranch).merge", value: "refs/heads/\(destinationBranch)", at: path, verbose: false)
            }
        }
    }

    /// 删除远程分支，等价于 `git push <remote> --delete <branch>`。
    public static func deleteRemoteBranch(named branchName: String, remote: String = "origin", at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let trimmedName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedName.isEmpty == false, trimmedRemote.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let shortBranchName = trimmedName.hasPrefix(trimmedRemote + "/")
                ? String(trimmedName.dropFirst(trimmedRemote.count + 1))
                : trimmedName

            guard shortBranchName.isEmpty == false && shortBranchName != "HEAD" else {
                throw LibGit2Error.invalidReference
            }

            try pushRefspecs([":refs/heads/\(shortBranchName)"], at: path, remote: trimmedRemote, verbose: verbose)
        }
    }

    /// 推送本地标签到远程。
    public static func pushTag(named tagName: String, remote: String = "origin", at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedName.isEmpty == false, trimmedRemote.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            try pushRefspecs(["refs/tags/\(trimmedName):refs/tags/\(trimmedName)"], at: path, remote: trimmedRemote, verbose: verbose)
        }
    }

    /// 删除远程标签。
    public static func deleteRemoteTag(named tagName: String, remote: String = "origin", at path: String, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines)

            guard trimmedName.isEmpty == false, trimmedRemote.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            try pushRefspecs([":refs/tags/\(trimmedName)"], at: path, remote: trimmedRemote, verbose: verbose)
        }
    }

    /// 使用指定 refspec 推送到远程仓库。
    public static func pushRefspecs(_ refspecs: [String], at path: String, remote: String = "origin", verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            NetworkCallbacks.verbose = verbose
            if NetworkCallbacks.verbose { os_log("\(t)Pushing to remote: \(remote)") }

            let trimmedRefspecs = refspecs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }

            guard trimmedRefspecs.isEmpty == false else {
                throw LibGit2Error.invalidReference
            }

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var remoteObj: OpaquePointer? = nil
            defer { if remoteObj != nil { git_remote_free(remoteObj) } }

            let result = git_remote_lookup(&remoteObj, repo, remote)

            if result != 0 {
                throw LibGit2Error.remoteNotFound(remote)
            }

            // 尊重 ~/.ssh/config 中非 22 端口的 SSH 服务（否则 libssh2 连默认端口报 Failed getting banner）
            let restoreRemoteURL = rewriteRemoteURLForSSHConfig(repo: repo, remoteName: remote, remote: &remoteObj)
            defer { restoreRemoteURL?() }

            guard let remotePtr = remoteObj else {
                throw LibGit2Error.remoteNotFound(remote)
            }

            let refspecPointers = trimmedRefspecs.map { strdup($0) }
            defer { refspecPointers.forEach { free($0) } }

            var gitRefspecs = git_strarray()
            var refspecArray = refspecPointers
            let result_strarray = refspecArray.withUnsafeMutableBufferPointer { buffer -> Int32 in
                gitRefspecs.strings = buffer.baseAddress
                gitRefspecs.count = trimmedRefspecs.count

                var pushOpts = git_push_options()
                git_push_init_options(&pushOpts, UInt32(GIT_PUSH_OPTIONS_VERSION))

                // 设置进度回调
                pushOpts.callbacks.push_transfer_progress = NetworkCallbacks.pushTransferProgress
                let verbosePayloadPtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
                verbosePayloadPtr.pointee = verbose

                // 设置凭据回调
                pushOpts.callbacks.credentials = gitCredentialCallback
                pushOpts.callbacks.payload = UnsafeMutableRawPointer(verbosePayloadPtr)

                let result = git_remote_push(remotePtr, &gitRefspecs, &pushOpts)
                verbosePayloadPtr.deallocate()
                return result
            }

            if result_strarray != 0 {
                var errorMessage = "Unknown push error"

                // 尝试从 libgit2 获取错误消息
                if let error = git_error_last() {
                    let message = String(cString: error.pointee.message)
                    if !message.isEmpty {
                        errorMessage = message
                    }
                }

                // 如果没有具体的错误消息，提供通用说明
                if errorMessage == "Unknown push error" || errorMessage.isEmpty {
                    errorMessage = "Push failed - please check your credentials and network connection"
                }

                if NetworkCallbacks.verbose { os_log("\(t)Push failed with code \(result_strarray): \(errorMessage)") }

                // 检查是否是认证错误
                if isAuthenticationError(result_strarray, errorMessage: errorMessage) {
                    throw LibGit2Error.authenticationError
                }

                // 检查是否是网络/SSL 错误
                if isNetworkError(result_strarray, errorMessage: errorMessage) {
                    throw LibGit2Error.networkError(Int(result_strarray))
                }

                throw LibGit2Error.pushFailed(errorMessage)
            }

            if NetworkCallbacks.verbose { os_log("\(t)Push completed successfully") }
        }
    }

    /// 从 upstream 拉取并合并到当前分支。
    ///
    /// upstream 由 `branch.<name>.remote` / `branch.<name>.merge` 决定，
    /// 不再假定远程分支名与本地分支名相同。
    ///
    /// **安全性**：合并或快进前会检查工作区。若存在会与传入更新冲突的本地
    /// 改动，则抛出 `localChangesWouldBeOverwritten`，绝不静默丢弃用户改动
    /// （旧实现使用 `GIT_CHECKOUT_FORCE`，这是数据丢失级缺陷）。
    ///
    /// - Parameters:
    ///   - path: 仓库路径
    ///   - strategy: 拉取策略（merge / fast-forward-only / rebase）
    ///   - verbose: 是否输出详细日志
    public static func pull(
        at path: String,
        strategy: PullStrategy = .merge,
        verbose: Bool = true
    ) throws {
        try LibGit2.serialized(at: path) {
            NetworkCallbacks.verbose = verbose

            guard let binding = try upstreamBinding(at: path) else {
                let branch = (try? currentBranchName(at: path)) ?? nil
                throw LibGit2Error.noUpstreamConfigured(branch: branch ?? "HEAD")
            }

            if NetworkCallbacks.verbose {
                os_log("\(t)Pulling \(binding.localBranch) from \(binding.remote)/\(binding.remoteBranch)")
            }

            let repo = try openRepositoryUnlocked(at: path)
            defer { git_repository_free(repo) }

            var remoteObj: OpaquePointer?
            defer { if remoteObj != nil { git_remote_free(remoteObj) } }
            guard git_remote_lookup(&remoteObj, repo, binding.remote) == 0, remoteObj != nil else {
                throw LibGit2Error.remoteNotFound(binding.remote)
            }

            // 尊重 ~/.ssh/config 中非 22 端口的 SSH 服务（否则 libssh2 连默认端口报 Failed getting banner）
            let restoreRemoteURL = rewriteRemoteURLForSSHConfig(repo: repo, remoteName: binding.remote, remote: &remoteObj)
            defer { restoreRemoteURL?() }

            guard let remotePtr = remoteObj else {
                throw LibGit2Error.remoteNotFound(binding.remote)
            }

            try fetchIntoRemoteTracking(
                repo: repo,
                remote: remotePtr,
                refspec: binding.fetchRefspec,
                verbose: verbose
            )

            // 解析 upstream 引用到具体 commit。必须显式检查：不在时通常意味着
            // 该远程分支从未被 fetch 过，而非"已是最新"。
            var remoteOID = git_oid()
            guard git_reference_name_to_id(&remoteOID, repo, binding.remoteTrackingReference) == 0 else {
                throw LibGit2Error.upstreamReferenceNotFound(binding.remoteTrackingReference)
            }

            var remoteAnnotated: OpaquePointer?
            defer { if remoteAnnotated != nil { git_annotated_commit_free(remoteAnnotated) } }
            guard git_annotated_commit_lookup(&remoteAnnotated, repo, &remoteOID) == 0,
                  let remoteCommit = remoteAnnotated else {
                throw LibGit2Error.pullFailed("Failed to resolve upstream commit.")
            }

            // 合并分析：libgit2 以 HEAD 隐含本地侧，只需传入 upstream。
            var analysis = git_merge_analysis_t(rawValue: 0)
            var preference = git_merge_preference_t(rawValue: 0)
            var analysisCommits: [OpaquePointer?] = [remoteCommit]
            _ = analysisCommits.withUnsafeMutableBufferPointer { buffer in
                git_merge_analysis(&analysis, &preference, repo, buffer.baseAddress, 1)
            }

            if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
                if NetworkCallbacks.verbose { os_log("\(t)Already up to date") }
                return
            }

            let canFastForward = analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0

            if canFastForward {
                if strategy == .fastForwardOnly || strategy == .merge || strategy == .rebase {
                    try fastForward(
                        repo: repo,
                        localReference: binding.localReference,
                        targetOID: remoteOID
                    )
                    os_log("\(t)Pull completed (fast-forward)")
                    return
                }
            }

            guard strategy != .fastForwardOnly else {
                throw LibGit2Error.pullFailed("Not a fast-forward update; refusing to merge.")
            }

            if strategy == .rebase {
                do {
                    try rebase(
                        at: path,
                        upstream: binding.remoteTrackingReference,
                        onto: binding.remoteTrackingReference,
                        verbose: verbose
                    )
                } catch LibGit2Error.mergeConflict {
                    throw LibGit2Error.mergeConflict
                } catch {
                    throw LibGit2Error.pullFailed(error.localizedDescription)
                }
                if NetworkCallbacks.verbose {
                    os_log("\(t)Pull completed (rebase)")
                }
                return
            }

            // 普通合并：先做安全检查，禁止覆盖未提交改动。
            try mergeUpstream(repo: repo, upstreamCommit: remoteCommit)
            if NetworkCallbacks.verbose {
                os_log("\(t)Pull completed (merge)")
            }
        }
    }

    /// 拉取策略。
    public enum PullStrategy: String, Sendable, CaseIterable {
        /// 允许快进，否则创建合并提交（等价 `git pull` 默认行为）。
        case merge
        /// 仅允许快进，否则失败（等价 `git pull --ff-only`）。
        case fastForwardOnly
        /// 变基后快进（等价 `git pull --rebase`）。
        case rebase
    }

    // MARK: - Pull 内部步骤

    /// 执行 fetch，把 upstream 更新写入远程跟踪引用。
    private static func fetchIntoRemoteTracking(
        repo: OpaquePointer,
        remote: OpaquePointer,
        refspec: String,
        verbose: Bool
    ) throws {
        var fetchOpts = git_fetch_options()
        git_fetch_init_options(&fetchOpts, UInt32(GIT_FETCH_OPTIONS_VERSION))
        fetchOpts.callbacks.credentials = gitCredentialCallback
        fetchOpts.callbacks.transfer_progress = NetworkCallbacks.transferProgress

        let verbosePayload = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        verbosePayload.pointee = verbose
        defer { verbosePayload.deallocate() }
        fetchOpts.callbacks.payload = UnsafeMutableRawPointer(verbosePayload)

        let refspecPointer = strdup(refspec)
        defer { free(refspecPointer) }

        var refspecs = git_strarray()
        var refspecArray: [UnsafeMutablePointer<CChar>?] = [refspecPointer]
        let result = refspecArray.withUnsafeMutableBufferPointer { buffer -> Int32 in
            refspecs.strings = buffer.baseAddress
            refspecs.count = 1
            return git_remote_fetch(remote, &refspecs, &fetchOpts, nil)
        }

        guard result == 0 else {
            throw networkError(from: result, context: "Fetch failed")
        }
    }

    /// 快进本地分支引用并安全更新工作区。
    private static func fastForward(
        repo: OpaquePointer,
        localReference: String,
        targetOID: git_oid
    ) throws {
        // 先用 SAFE 策略更新工作区：若存在冲突的本地改动会直接失败，
        // 而不是像 GIT_CHECKOUT_FORCE 那样覆盖用户文件。
        var checkoutOpts = git_checkout_options()
        git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

        var targetOID = targetOID
        var targetObject: OpaquePointer?
        defer { if targetObject != nil { git_object_free(targetObject) } }
        guard git_object_lookup(&targetObject, repo, &targetOID, GIT_OBJECT_COMMIT) == 0,
              let tree = targetObject else {
            throw LibGit2Error.pullFailed("Failed to resolve fast-forward target tree.")
        }
        let checkoutResult = git_checkout_tree(repo, tree, &checkoutOpts)
        if checkoutResult != 0 {
            throw errorFromCheckoutResult(checkoutResult, context: "pull")
        }

        // 工作区已安全更新，再移动分支引用。
        var reference: OpaquePointer?
        defer { if reference != nil { git_reference_free(reference) } }
        guard git_reference_lookup(&reference, repo, localReference) == 0, let reference else {
            throw LibGit2Error.pullFailed("Failed to lookup branch reference for fast-forward.")
        }

        var updatedRef: OpaquePointer?
        defer { if updatedRef != nil { git_reference_free(updatedRef) } }
        let setTargetResult = git_reference_set_target(
            &updatedRef,
            reference,
            &targetOID,
            "pull: fast-forward"
        )
        guard setTargetResult == 0 else {
            throw LibGit2Error.pullFailed("Failed to fast-forward branch reference.")
        }
    }

    /// 执行一次普通合并，并在无法安全合并时回滚工作区。
    ///
    /// 返回 libgit2 的状态码；冲突（`GIT_ECONFLICT`）不是错误，而是需要用户
    /// 介入的正常状态，因此不抛出，交由上层 UI 展示冲突解决界面。
    private static func mergeUpstream(
        repo: OpaquePointer,
        upstreamCommit: OpaquePointer
    ) throws {
        var mergeOpts = git_merge_options()
        git_merge_init_options(&mergeOpts, UInt32(GIT_MERGE_OPTIONS_VERSION))

        var checkoutOpts = git_checkout_options()
        git_checkout_init_options(&checkoutOpts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        checkoutOpts.checkout_strategy = GIT_CHECKOUT_SAFE.rawValue

        var upstreamCommits: [OpaquePointer?] = [upstreamCommit]
        let mergeResult = upstreamCommits.withUnsafeMutableBufferPointer { buffer -> Int32 in
            var mergeOpts = mergeOpts
            var checkoutOpts = checkoutOpts
            return git_merge(repo, buffer.baseAddress, 1, &mergeOpts, &checkoutOpts)
        }

        if mergeResult == GIT_ECONFLICT.rawValue {
            // 留下 MERGE_HEAD 与冲突标记，交给用户解决。
            throw LibGit2Error.mergeConflict
        }

        guard mergeResult == 0 else {
            // 失败（例如本地改动会被覆盖）时清理中间状态并上抛可读错误。
            git_repository_state_cleanup(repo)
            throw errorFromCheckoutResult(mergeResult, context: "pull")
        }

        // 合并成功则创建合并提交，使 HEAD 前移（与 git pull 一致）。
        try commitMerge(repo: repo)
    }

    /// 为已完成的合并创建合并提交。
    private static func commitMerge(repo: OpaquePointer) throws {
        // 无冲突且索引已就绪，直接提交。
        var index: OpaquePointer?
        defer { if index != nil { git_index_free(index) } }
        guard git_repository_index(&index, repo) == 0, let index else {
            throw LibGit2Error.cannotGetIndex
        }

        guard git_index_has_conflicts(index) == 0 else {
            throw LibGit2Error.mergeConflict
        }

        var treeOID = git_oid()
        guard git_index_write_tree_to(&treeOID, index, repo) == 0 else {
            throw LibGit2Error.cannotWriteTree
        }

        var tree: OpaquePointer?
        defer { if tree != nil { git_tree_free(tree) } }
        guard git_tree_lookup(&tree, repo, &treeOID) == 0, let tree else {
            throw LibGit2Error.cannotWriteTree
        }

        var headCommit: OpaquePointer?
        defer { if headCommit != nil { git_commit_free(headCommit) } }
        var headOID = git_oid()
        guard git_reference_name_to_id(&headOID, repo, "HEAD") == 0,
              git_commit_lookup(&headCommit, repo, &headOID) == 0,
              let headCommit else {
            throw LibGit2Error.cannotGetHEAD
        }

        var mergeHeadOID = git_oid()
        guard git_reference_name_to_id(&mergeHeadOID, repo, "MERGE_HEAD") == 0 else {
            throw LibGit2Error.invalidRepositoryState("MERGE_HEAD is missing; nothing to commit.")
        }
        var mergeHeadCommit: OpaquePointer?
        defer { if mergeHeadCommit != nil { git_commit_free(mergeHeadCommit) } }
        guard git_commit_lookup(&mergeHeadCommit, repo, &mergeHeadOID) == 0,
              let mergeHeadCommit else {
            throw LibGit2Error.invalidRepositoryState("MERGE_HEAD does not reference a valid commit.")
        }

        var signature: UnsafeMutablePointer<git_signature>?
        defer {
            if signature != nil { git_signature_free(signature) }
        }
        guard git_signature_default(&signature, repo) == 0, let signature else {
            throw LibGit2Error.commitFailed
        }

        var parents: [OpaquePointer?] = [headCommit, mergeHeadCommit]
        var newCommitOID = git_oid()
        let commitResult = parents.withUnsafeMutableBufferPointer { buffer -> Int32 in
            let mutableBuffer = buffer
            return git_commit_create(
                &newCommitOID,
                repo,
                "HEAD",
                signature,
                signature,
                nil,
                "Merge branch 'upstream'",
                tree,
                2,
                mutableBuffer.baseAddress
            )
        }
        guard commitResult == 0 else {
            throw LibGit2Error.commitFailed
        }

        git_repository_state_cleanup(repo)
    }

    /// 把 libgit2 返回码映射为语义化错误。
    private static func networkError(from code: Int32, context: String) -> LibGit2Error {
        let message = git_error_last().map { String(cString: $0.pointee.message) } ?? context
        if isAuthenticationError(code, errorMessage: message) {
            return .authenticationError
        }
        if isNetworkError(code, errorMessage: message) {
            return .networkError(Int(code))
        }
        return .pullFailed(message)
    }


    /// Fetch remote refs without merging them into the current branch.
    public static func fetch(at path: String, remote: String = "origin", prune: Bool = true, verbose: Bool = true) throws {
        try LibGit2.serialized(at: path) {
            NetworkCallbacks.verbose = verbose

            let repo = try openRepository(at: path)
            defer { git_repository_free(repo) }

            var remoteObj: OpaquePointer?
            defer { if remoteObj != nil { git_remote_free(remoteObj) } }

            guard git_remote_lookup(&remoteObj, repo, remote) == 0, remoteObj != nil else {
                throw LibGit2Error.remoteNotFound(remote)
            }

            // 尊重 ~/.ssh/config 中非 22 端口的 SSH 服务（否则 libssh2 连默认端口报 Failed getting banner）
            let restoreRemoteURL = rewriteRemoteURLForSSHConfig(repo: repo, remoteName: remote, remote: &remoteObj)
            defer { restoreRemoteURL?() }

            var fetchOpts = git_fetch_options()
            git_fetch_init_options(&fetchOpts, UInt32(GIT_FETCH_OPTIONS_VERSION))
            fetchOpts.callbacks.credentials = gitCredentialCallback
            fetchOpts.callbacks.transfer_progress = NetworkCallbacks.transferProgress
            fetchOpts.prune = prune ? GIT_FETCH_PRUNE : GIT_FETCH_NO_PRUNE

            let verbosePayloadPtr = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
            verbosePayloadPtr.pointee = verbose
            defer { verbosePayloadPtr.deallocate() }
            fetchOpts.callbacks.payload = UnsafeMutableRawPointer(verbosePayloadPtr)

            let result = git_remote_fetch(remoteObj, nil, &fetchOpts, nil)
            if result != 0 {
                if let error = git_error_last() {
                    let message = String(cString: error.pointee.message)
                    if isAuthenticationError(result, errorMessage: message) {
                        throw LibGit2Error.authenticationError
                    }
                    if isNetworkError(result, errorMessage: message) {
                        throw LibGit2Error.networkError(Int(result))
                    }
                    throw LibGit2Error.pullFailed(message)
                }
                throw LibGit2Error.pullFailed("Fetch failed")
            }
        }
    }

    /// 克隆远程仓库
    /// - Parameters:
    ///   - url: 远程仓库 URL
    ///   - destination: 目标路径
    ///   - branch: 要克隆的分支（nil 表示默认分支）
    ///   - onProgress: 接收 libgit2 报告的对象、delta 和字节数进度
    ///   - cancellation: 协作式取消令牌，可在传输中途中止
    public static func clone(
        url: String,
        to destination: String,
        branch: String? = nil,
        onProgress: (@Sendable (LibGit2CloneProgress) -> Void)? = nil,
        cancellation: GitCancellationToken? = nil
    ) throws {
        try cancellation?.checkCancellation()

        // clone 是最耗时的操作，必须以目标仓库为队列作用域，避免阻塞全局队列。
        // 目标路径此刻通常尚不存在，队列池只把它当作稳定 key，不要求路径有效。
        try LibGit2.serialized(at: destination) {
            // 尊重 ~/.ssh/config 中非 22 端口的 SSH 服务（否则 libssh2 连默认端口报 Failed getting banner）
            let effectiveURL = SSHConfig.normalizedURL(for: url) ?? url
            os_log("\(t)Cloning repository from: \(effectiveURL)")

            var cloneOpts = git_clone_options()
            git_clone_init_options(&cloneOpts, UInt32(GIT_CLONE_OPTIONS_VERSION))

            defer {
                if let branchPointer = cloneOpts.checkout_branch {
                    free(UnsafeMutableRawPointer(mutating: branchPointer))
                }
            }

            // 设置分支
            if let branch = branch {
                cloneOpts.checkout_branch = UnsafePointer(strdup(branch))
            }

            // 设置 clone 专用进度回调。payload 必须在整个同步 git_clone 调用期间保持有效。
            let progressPayload = CloneProgressPayload(
                onProgress: onProgress,
                cancellation: cancellation
            )
            cloneOpts.fetch_opts.callbacks.transfer_progress = NetworkCallbacks.cloneTransferProgress
            cloneOpts.fetch_opts.callbacks.payload = Unmanaged.passUnretained(progressPayload).toOpaque()

            var repo: OpaquePointer? = nil
            let result = withExtendedLifetime(progressPayload) {
                git_clone(&repo, effectiveURL, destination, &cloneOpts)
            }

            if result != 0 || repo == nil {
                if cancellation?.isCancelled == true {
                    // 取消发生在传输中途：清理可能残留的半成品目录，避免留下
                    // 一个无法使用、又会让下次 clone 判定为"目录非空"的仓库。
                    try? FileManager.default.removeItem(atPath: destination)
                    throw CancellationError()
                }
                let message = git_error_last().map { String(cString: $0.pointee.message) }
                os_log("\(t)Clone failed: \(message ?? "unknown error")")
                throw LibGit2Error.cloneFailed(message: message)
            }

            git_repository_free(repo)

            os_log("🐚 LibGit2: Repository cloned successfully to: %{public}@", destination)
        }
    }

    /// 检查远程 URL 是否为有效的 Git 仓库
    /// - Parameter url: 远程仓库 URL
    /// - Returns: 如果是有效的 Git 仓库返回 true
    public static func isValidGitRepository(_ url: String, at path: String) -> Bool {
        return LibGit2.serialized(at: path) {
            guard let repo = try? openRepository(at: path) else { return false }
            defer { git_repository_free(repo) }

            var remote: OpaquePointer? = nil
            defer {
                if remote != nil {
                    git_remote_free(remote)
                }
            }

            // 使用 git_remote_create_anonymous 来测试 URL
            let result = git_remote_create_anonymous(&remote, repo, url)

            return result == 0
        }
    }
}
