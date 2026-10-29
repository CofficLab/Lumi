import Foundation

/// 收集 App Store Connect 提交审核所需的结构化快照。
///
/// 负责把分散在多个 ASC 资源里的信息（版本、Build、本地化、风险提示）
/// 汇总成一份 `ASCSubmissionPreview`，供时间线消息展示。
enum ASCSubmissionSnapshotBuilder {
    /// 读取版本、关联 Build 与本地化，生成提交快照。
    ///
    /// 采集过程中的单点失败不应中断整体流程：拿不到 Build 就只缺 Build 字段，
    /// 拿不到本地化就只缺本地化字段。这样即使 ASC 部分接口抖动，
    /// 用户仍能看到「当前将提交什么」的大部分信息。
    ///
    /// - Parameters:
    ///   - client: ASC 客户端。
    ///   - versionID: 目标版本 ID。
    ///   - assignedBuildID: 已关联的 Build ID；未关联时传 nil。
    ///   - stage: 当前阶段。
    /// - Returns: 提交快照（含提交前的风险提示）。
    static func build(
        client: ConnectClient,
        versionID: String,
        assignedBuildID: String?,
        stage: ASCSubmissionStage
    ) async -> ASCSubmissionPreview {
        var preview = ASCSubmissionPreview(
            versionID: versionID,
            versionString: versionID,
            platform: "IOS",
            platformLabel: "iOS",
            appStoreState: "-",
            appVersionState: "-",
            stage: stage
        )

        // 1. 版本主体信息
        var version: AppStoreVersion?
        if let fetched = try? await client.readVersion(id: versionID) {
            version = fetched
            preview.versionString = fetched.versionString
            preview.platform = fetched.platform
            preview.platformLabel = fetched.platformLabel
            preview.appStoreState = fetched.appStoreState
            preview.appVersionState = fetched.appVersionState
            preview.releaseType = fetched.releaseType
        }

        // 2. 关联 Build
        if let assignedBuildID,
           let build = await readBuild(client: client, versionID: versionID, buildID: assignedBuildID) {
            preview.buildNumber = build.version
            preview.buildVersionString = build.preReleaseVersionString
            preview.buildProcessingState = build.processingState
            preview.buildExpired = build.expired
        }

        // 3. 本地化
        let localizations = (try? await client.listLocalizations(versionID: versionID)) ?? []
        preview.localizations = localizations.map { localization in
            ASCSubmissionLocalization(
                locale: localization.locale,
                hasDescription: !localization.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                hasWhatsNew: !localization.whatsNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                hasKeywords: !localization.keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isDescriptionEmpty: localization.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }

        // 4. 提交前的风险提示
        preview.warnings = await collectWarnings(
            client: client,
            versionID: versionID,
            version: version,
            localizations: localizations,
            hasAssignedBuild: assignedBuildID != nil
        )

        return preview
    }

    /// 汇总提交前的风险提示。
    ///
    /// 这些提示只描述「还差什么」，帮助用户在提交前补齐缺失项。
    private static func collectWarnings(
        client: ConnectClient,
        versionID: String,
        version: AppStoreVersion?,
        localizations: [AppStoreVersionLocalization],
        hasAssignedBuild: Bool
    ) async -> [String] {
        var warnings: [String] = []

        // 1. 必须已关联 Build
        if !hasAssignedBuild {
            warnings.append("No build is assigned to this version. Use assign-build first.")
        }

        // 2. 版本属性
        if let version, version.copyright?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            warnings.append("copyright is not set. Use update-version to set it if required.")
        }

        // 3. 年龄分级（app 级声明，ASC API 只能读取不能创建）
        if (try? await client.readAgeRatingDeclaration(versionID: versionID)) == nil {
            warnings.append(
                "No age-rating declaration found. The ASC API cannot create one — "
                + "complete the questionnaire once for this app via the App Store Connect website "
                + "(App Information → Age Ratings → Set Up Age Ratings → Save), "
                + "then use set-age-rating to update programmatically."
            )
        }

        // 4. 本地化信息
        if localizations.isEmpty {
            warnings.append("No localizations found. Use create-localization to add at least one locale with description.")
        } else {
            for localization in localizations where localization.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("Localization '\(localization.locale)' has an empty description. Update-localization to fill it in.")
            }
        }

        return warnings
    }

    /// 读取指定 Build。
    ///
    /// ASC 没有按 ID 读取单个 build 的查询参数（`/v1/builds/{id}` 会 404），
    /// 因此这里经版本反查 app，再从 app 的 build 列表中定位目标构建。
    private static func readBuild(
        client: ConnectClient,
        versionID: String,
        buildID: String
    ) async -> ConnectBuild? {
        guard let appID = try? await client.resolveAppID(versionID: versionID),
              let builds = try? await client.listBuilds(appID: appID) else {
            return nil
        }
        return builds.first { $0.id == buildID }
    }
}
