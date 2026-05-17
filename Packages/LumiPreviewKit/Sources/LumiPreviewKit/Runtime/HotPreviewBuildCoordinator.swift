import Foundation

/// Hot 预览构建协调器：通过指纹机制避免重复编译。
///
/// 当同一个编译策略的源码指纹未发生变化时，直接复用上次编译结果（`.reused`）。
/// 支持并发安全：多个预览请求同时触发同一策略的编译时，自动合并为一次（`.joined`）。
actor HotPreviewBuildCoordinator {
    /// 构建结果类型。
    enum Result: Sendable {
        /// 执行了一次新的编译。
        case built
        /// 指纹未变，复用了上次编译结果。
        case reused
        /// 加入了一个正在进行的编译，等待其完成。
        case joined
    }

    private struct InFlightKey: Hashable {
        let strategy: LumiPreviewFacade.BuildStrategy
        let fingerprint: String
    }

    private var fingerprints: [LumiPreviewFacade.BuildStrategy: String] = [:]
    private var inFlightBuilds: [InFlightKey: Task<Void, Error>] = [:]

    /// 根据指纹判断是否需要执行编译。
    ///
    /// - Parameters:
    ///   - strategy: 编译策略。
    ///   - fingerprint: 源码内容指纹（`nil` 时强制编译）。
    ///   - operation: 实际的编译操作。
    /// - Returns: 构建结果（`built`/`reused`/`joined`）。
    func buildIfNeeded(
        strategy: LumiPreviewFacade.BuildStrategy,
        fingerprint: String?,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws -> Result {
        guard let fingerprint else {
            try await operation()
            return .built
        }

        if fingerprints[strategy] == fingerprint {
            return .reused
        }

        let key = InFlightKey(strategy: strategy, fingerprint: fingerprint)
        if let build = inFlightBuilds[key] {
            try await build.value
            fingerprints[strategy] = fingerprint
            return .joined
        }

        let build = Task {
            try await operation()
        }
        inFlightBuilds[key] = build

        do {
            try await build.value
        } catch {
            inFlightBuilds[key] = nil
            throw error
        }

        inFlightBuilds[key] = nil
        fingerprints[strategy] = fingerprint
        return .built
    }
}
