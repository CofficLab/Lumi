import Foundation

/// 启动失败的归因类别。
public enum BootstrapFailureKind: Equatable, Sendable {
    /// 磁盘可用空间不足，应用无法可靠启动。
    case insufficientDiskSpace(availableBytes: Int64, requiredBytes: Int64)
    /// 某个插件在生命周期阶段启动失败（磁盘空间正常或无法判定）。
    case pluginBootFailed
    /// 无法归因的启动失败。
    case unknown
}

/// 启动失败的上下文。
///
/// 由宿主从原始错误里抽取后传入。本包刻意不依赖 KernelCore，因此不认识
/// `KernelCoreError` 本身——抽取归属信息是宿主的职责，这样本包可以保持零依赖，
/// 同时让插件与宿主都能复用同一套归因规则。
public struct BootstrapFailureContext: Equatable, Sendable {
    /// 失败的插件 ID（可归因时才有）。
    public let pluginID: String?
    /// 失败的生命周期阶段（可归因时才有）。
    public let phase: String?
    /// 原始报错文本。
    public let technicalDetail: String

    public init(pluginID: String?, phase: String?, technicalDetail: String) {
        self.pluginID = pluginID
        self.phase = phase
        self.technicalDetail = technicalDetail
    }
}

/// 启动失败的完整报告。
///
/// 无论归因成什么，`technicalDetail` 都必须保留原始报错：归因决定**标题和
/// 建议动作**，技术详情决定**用户能不能自己排查**。二者不能互相替代。
public struct BootstrapFailureReport: Equatable, Sendable {
    /// 归因类别。
    public let kind: BootstrapFailureKind
    /// 失败的插件 ID（可归因时才有）。
    public let pluginID: String?
    /// 失败的生命周期阶段（可归因时才有）。
    public let phase: String?
    /// 原始报错文本，永远保留。
    public let technicalDetail: String

    public init(
        kind: BootstrapFailureKind,
        pluginID: String? = nil,
        phase: String? = nil,
        technicalDetail: String
    ) {
        self.kind = kind
        self.pluginID = pluginID
        self.phase = phase
        self.technicalDetail = technicalDetail
    }
}

/// 把启动失败归因成用户可读的失败类型。
///
/// - Important: 归因**不依赖**错误本身携带根因——SwiftData 已经把根因销毁了。
///   判据是「主动探测到的卷容量」：磁盘确实不够时，无论插件抛的是哪一类错误，
///   磁盘不足都是一个真实存在、且必须先解决的问题，标题应当如实告知用户；
///   同时 `technicalDetail` 原样保留，避免掩盖真正的编程错误。
public enum BootstrapFailureClassifier {

    /// 归因启动失败。
    ///
    /// - Parameters:
    ///   - context: 宿主从原始错误里抽取的上下文。
    ///   - space: 装配前探测到的磁盘空间判定结果。
    /// - Returns: 归因报告。
    public static func classify(
        context: BootstrapFailureContext,
        space: BootstrapSpaceVerdict
    ) -> BootstrapFailureReport {
        switch space {
        case .insufficient(let availableBytes, let requiredBytes):
            return BootstrapFailureReport(
                kind: .insufficientDiskSpace(
                    availableBytes: availableBytes,
                    requiredBytes: requiredBytes
                ),
                pluginID: context.pluginID,
                phase: context.phase,
                technicalDetail: context.technicalDetail
            )

        case .sufficient, .unknown:
            if context.pluginID != nil || context.phase != nil {
                return BootstrapFailureReport(
                    kind: .pluginBootFailed,
                    pluginID: context.pluginID,
                    phase: context.phase,
                    technicalDetail: context.technicalDetail
                )
            }
            return BootstrapFailureReport(
                kind: .unknown,
                technicalDetail: context.technicalDetail
            )
        }
    }
}
