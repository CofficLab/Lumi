import Foundation

/// App Store Connect 提交审核的阶段。
///
/// 提交工具会在「提交前」和「提交后」各产生一条时间线消息，
/// 用户据此判断当前到底提交了什么、提交是否成功。
enum ASCSubmissionStage: String, Codable, Equatable, Sendable {
    /// 即将提交：已收集版本 / Build / 本地化信息，等待提交动作。
    case preview
    /// 已提交审核。
    case submitted
    /// 提交失败。
    case failed
}

/// 单个商店本地化的元信息摘要。
///
/// 只保留提交前需要向用户确认的关键字段是否就绪，不搬运完整文案，
/// 避免时间线消息携带大量无关内容。
struct ASCSubmissionLocalization: Codable, Equatable, Sendable {
    /// 区域码，例如 `en-US`、`zh-Hans`。
    var locale: String
    /// 描述是否已填写。
    var hasDescription: Bool
    /// 「新功能」说明是否已填写。
    var hasWhatsNew: Bool
    /// 关键词是否已填写。
    var hasKeywords: Bool
    /// 描述是否为空（用于生成提交前提示）。
    var isDescriptionEmpty: Bool

    init(
        locale: String,
        hasDescription: Bool,
        hasWhatsNew: Bool,
        hasKeywords: Bool,
        isDescriptionEmpty: Bool
    ) {
        self.locale = locale
        self.hasDescription = hasDescription
        self.hasWhatsNew = hasWhatsNew
        self.hasKeywords = hasKeywords
        self.isDescriptionEmpty = isDescriptionEmpty
    }
}

/// App Store Connect 提交审核的结构化快照。
///
/// 这份数据被 JSON 编码进 `Message.metadata`，由 ASC 提交时间线渲染器
/// 还原成可读卡片。字段只描述「当前将提交什么」：
/// 版本号、Build、平台、审核状态、本地化情况以及提交前的风险提示。
struct ASCSubmissionPreview: Codable, Equatable, Sendable {
    /// App 名称（若能解析到）。
    var appName: String?
    /// App Store Version 资源 ID。
    var versionID: String
    /// 营销版本号，例如 `1.2.0`。
    var versionString: String
    /// 平台原始值，例如 `IOS`。
    var platform: String
    /// 平台展示名，例如 `iOS`。
    var platformLabel: String
    /// App Store 状态，例如 `READY_FOR_SALE`、`PREPARE_FOR_SUBMISSION`。
    var appStoreState: String
    /// 版本状态，例如 `RELEASED`、`PREPARE_FOR_SUBMISSION`。
    var appVersionState: String
    /// 发布类型，例如 `AFTER_APPROVAL`、`MANUAL`。
    var releaseType: String?
    /// 关联 Build 的构建号。
    var buildNumber: String?
    /// 关联 Build 对应的预发布版本号。
    var buildVersionString: String?
    /// Build 的处理状态，例如 `VALID`、`PROCESSING`。
    var buildProcessingState: String?
    /// Build 是否已过期。
    var buildExpired: Bool
    /// 已就绪的本地化列表。
    var localizations: [ASCSubmissionLocalization]
    /// 提交前的风险提示。
    var warnings: [String]
    /// 当前阶段。
    var stage: ASCSubmissionStage
    /// 提交成功后返回的 Review Submission ID。
    var submissionID: String?
    /// 失败原因。
    var errorMessage: String?

    init(
        appName: String? = nil,
        versionID: String,
        versionString: String,
        platform: String,
        platformLabel: String,
        appStoreState: String,
        appVersionState: String,
        releaseType: String? = nil,
        buildNumber: String? = nil,
        buildVersionString: String? = nil,
        buildProcessingState: String? = nil,
        buildExpired: Bool = false,
        localizations: [ASCSubmissionLocalization] = [],
        warnings: [String] = [],
        stage: ASCSubmissionStage = .preview,
        submissionID: String? = nil,
        errorMessage: String? = nil
    ) {
        self.appName = appName
        self.versionID = versionID
        self.versionString = versionString
        self.platform = platform
        self.platformLabel = platformLabel
        self.appStoreState = appStoreState
        self.appVersionState = appVersionState
        self.releaseType = releaseType
        self.buildNumber = buildNumber
        self.buildVersionString = buildVersionString
        self.buildProcessingState = buildProcessingState
        self.buildExpired = buildExpired
        self.localizations = localizations
        self.warnings = warnings
        self.stage = stage
        self.submissionID = submissionID
        self.errorMessage = errorMessage
    }

    /// Build 的展示文本，例如 `1.2.0 (45)`。
    var buildDisplayLabel: String? {
        guard let buildNumber, !buildNumber.isEmpty else { return nil }
        if let buildVersionString, !buildVersionString.isEmpty {
            return "\(buildVersionString) (\(buildNumber))"
        }
        return buildNumber
    }

    /// 是否存在提交前必须提示的问题。
    var hasWarnings: Bool {
        !warnings.isEmpty
    }

    /// 已就绪的本地化区域码。
    var localeLabels: [String] {
        localizations.map(\.locale)
    }
}
