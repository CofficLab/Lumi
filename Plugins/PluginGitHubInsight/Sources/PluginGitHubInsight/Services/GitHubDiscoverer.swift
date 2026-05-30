import Foundation
import SuperLogKit
import GitHubKit

/// 发现与项目推断技术生态相关的 GitHub 仓库。
///
/// 发现过程由框架、依赖、语言和 README 关键词构建出的仓库搜索查询驱动。
/// 结果会被评分，并保存为可能与当前项目相关的仓库线索。
public struct GitHubInsightDiscoverer: Sendable, SuperLog {
    /// 一组表达同一发现意图的 GitHub 查询，按从严格到宽松排列。
    private struct SearchPlan {
        /// 查询意图，用于日志定位。
        let name: String
        /// 可逐级回退的查询候选。
        let attempts: [SearchAttempt]
    }

    /// 单次 GitHub 仓库搜索请求。
    private struct SearchAttempt {
        /// 回退层级名称。
        let stage: String
        /// GitHub Search API 查询语句。
        let query: String
        /// GitHub 搜索排序字段。
        let sort: String?
        /// GitHub 搜索排序方向。
        let order: String?
    }

    /// 搜索 GitHub，并返回与项目画像最相关的仓库参考。
    ///
    /// - Parameters:
    ///   - profile: 用于构建搜索查询和相关性分数的项目画像。
    ///   - limitPerQuery: 每个生成查询请求的最大仓库数量。
    /// - Returns: 去重并按相关性排序后的知识库条目。
    public func discover(profile: GitHubInsightProjectProfile, limitPerQuery: Int = 8) async throws -> [GitHubInsightKBEntry] {
        var entriesByRepo: [String: GitHubInsightKBEntry] = [:]
        let searchPlans = buildSearchPlans(profile: profile)

        GitHubInsightPlugin.logger.info("\(Self.t)开始 GitHub 发现：project=\(profile.projectPath)，queries=\(searchPlans.count)，limitPerQuery=\(limitPerQuery)")

        for (index, plan) in searchPlans.enumerated() {
            var didAcceptRepository = false
            for (attemptIndex, attempt) in plan.attempts.enumerated() {
                GitHubInsightPlugin.logger.info("\(Self.t)请求 GitHub 仓库搜索[\(index + 1)/\(searchPlans.count)]：name=\(plan.name)，stage=\(attempt.stage)，query=\(attempt.query)")
                let result: GitHubSearchResult
                do {
                    result = try await GitHubAPIService.shared.searchRepositories(
                        query: attempt.query,
                        perPage: limitPerQuery,
                        sort: attempt.sort,
                        order: attempt.order
                    )
                } catch {
                    if entriesByRepo.isEmpty {
                        GitHubInsightPlugin.logger.error("\(Self.t)GitHub 搜索失败且暂无可用候选[\(index + 1)/\(searchPlans.count)]：name=\(plan.name)，stage=\(attempt.stage)，错误=\(error.localizedDescription)")
                        throw error
                    }

                    let entries = finalizedEntries(from: entriesByRepo)
                    GitHubInsightPlugin.logger.warning("\(Self.t)GitHub 搜索中断，返回已发现的部分结果[\(index + 1)/\(searchPlans.count)]：name=\(plan.name)，stage=\(attempt.stage)，错误=\(error.localizedDescription)，候选唯一仓库=\(entriesByRepo.count)，输出条目=\(entries.count)")
                    return entries
                }

                var archivedCount = 0
                var lowSignalForkCount = 0
                var existingDependencyCount = 0
                var acceptedCount = 0

                for repo in result.items {
                    guard repo.archived != true else {
                        archivedCount += 1
                        continue
                    }
                    if repo.fork == true && repo.stargazersCount < 50 {
                        lowSignalForkCount += 1
                        continue
                    }
                    if profile.dependencies.contains(where: { sameDependency($0, repo.name) || sameDependency($0, repo.fullName) }) {
                        existingDependencyCount += 1
                        continue
                    }

                    let entry = entry(from: repo, profile: profile)
                    if let existing = entriesByRepo[entry.fullName] {
                        if entry.relevanceScore > existing.relevanceScore {
                            entriesByRepo[entry.fullName] = entry
                        }
                    } else {
                        entriesByRepo[entry.fullName] = entry
                    }
                    acceptedCount += 1
                }

                GitHubInsightPlugin.logger.info("\(Self.t)GitHub 搜索完成[\(index + 1)/\(searchPlans.count)]：stage=\(attempt.stage)，total=\(result.totalCount)，返回=\(result.items.count)，接受=\(acceptedCount)，归档过滤=\(archivedCount)，低信号 fork 过滤=\(lowSignalForkCount)，已有依赖过滤=\(existingDependencyCount)，累计唯一仓库=\(entriesByRepo.count)")

                if acceptedCount > 0 {
                    didAcceptRepository = true
                    break
                }

                if attemptIndex < plan.attempts.count - 1 {
                    GitHubInsightPlugin.logger.info("\(Self.t)GitHub 搜索无可用结果，准备放宽查询[\(index + 1)/\(searchPlans.count)]：name=\(plan.name)，nextStage=\(plan.attempts[attemptIndex + 1].stage)")
                }
            }

            if !didAcceptRepository {
                GitHubInsightPlugin.logger.info("\(Self.t)GitHub 搜索计划未找到可用仓库[\(index + 1)/\(searchPlans.count)]：name=\(plan.name)")
            }
        }

        let entries = finalizedEntries(from: entriesByRepo)

        GitHubInsightPlugin.logger.info("\(Self.t)GitHub 发现结束：候选唯一仓库=\(entriesByRepo.count)，输出条目=\(entries.count)")
        return entries
    }

    /// 输出最终缓存条目，保证正常完成和部分结果返回使用相同排序规则。
    private func finalizedEntries(from entriesByRepo: [String: GitHubInsightKBEntry]) -> [GitHubInsightKBEntry] {
        entriesByRepo.values
            .sorted { lhs, rhs in
                if lhs.relevanceScore != rhs.relevanceScore { return lhs.relevanceScore > rhs.relevanceScore }
                return lhs.stars > rhs.stars
            }
            .prefix(24)
            .map { $0 }
    }

    /// 基于项目画像构建有数量上限的 GitHub 仓库搜索计划。
    private func buildSearchPlans(profile: GitHubInsightProjectProfile) -> [SearchPlan] {
        let language = profile.primaryLanguage.map { "language:\($0)" } ?? ""
        let recency = "pushed:>2024-01-01"

        var plans: [SearchPlan] = []
        let frameworks = Array(profile.frameworks.prefix(3))
        let dependencies = Array(profile.dependencies.prefix(4))
        let keywords = Array(profile.keywords.prefix(4))

        for framework in frameworks {
            plans.append(
                SearchPlan(
                    name: "framework-example:\(framework)",
                    attempts: [
                        attempt(stage: "strict", terms: [framework, language, "topic:example", "stars:>100", recency]),
                        attempt(stage: "relaxed", terms: [framework, language, "stars:>50", recency], sort: "stars"),
                        attempt(stage: "broad", terms: [framework, language, "stars:>10"], sort: "stars"),
                    ]
                )
            )
            plans.append(
                SearchPlan(
                    name: "framework-practice:\(framework)",
                    attempts: [
                        attempt(stage: "strict", terms: [framework, language, "best practices", "stars:>100", recency]),
                        attempt(stage: "relaxed", terms: [framework, language, "stars:>50", recency], sort: "stars"),
                        attempt(stage: "broad", terms: [framework, language, "stars:>10"], sort: "stars"),
                    ]
                )
            )
        }

        for dependency in dependencies {
            plans.append(
                SearchPlan(
                    name: "dependency-alternative:\(dependency)",
                    attempts: [
                        attempt(stage: "strict", terms: [dependency, "alternative", language, "stars:>100", recency]),
                        attempt(stage: "relaxed", terms: [dependency, language, "stars:>50", recency], sort: "stars"),
                        attempt(stage: "broad", terms: [dependency, "stars:>10"], sort: "stars"),
                    ]
                )
            )
        }

        let keywordQuery = (frameworks + keywords).prefix(4).joined(separator: " ")
        if !keywordQuery.isEmpty {
            plans.append(
                SearchPlan(
                    name: "profile-keywords",
                    attempts: [
                        attempt(stage: "strict", terms: [keywordQuery, language, "stars:>100", recency]),
                        attempt(stage: "relaxed", terms: [keywordQuery, language, "stars:>50"], sort: "stars"),
                    ]
                )
            )
        }

        if plans.isEmpty, let primaryLanguage = profile.primaryLanguage {
            plans.append(
                SearchPlan(
                    name: "language:\(primaryLanguage)",
                    attempts: [
                        attempt(stage: "strict", terms: ["language:\(primaryLanguage)", "stars:>100", recency], sort: "updated"),
                        attempt(stage: "broad", terms: ["language:\(primaryLanguage)", "stars:>100"], sort: "stars"),
                    ]
                )
            )
        }

        return Array(plans.prefix(8))
    }

    /// 构建单次搜索请求，并清理空白条件。
    private func attempt(stage: String, terms: [String], sort: String? = nil, order: String = "desc") -> SearchAttempt {
        SearchAttempt(
            stage: stage,
            query: terms.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " "),
            sort: sort,
            order: sort == nil ? nil : order
        )
    }

    /// 将 GitHub API 仓库响应转换为缓存条目。
    private func entry(
        from repo: GitHubRepository,
        profile: GitHubInsightProjectProfile
    ) -> GitHubInsightKBEntry {
        let score = relevanceScore(repo: repo, profile: profile)
        let pushedAt = parseGitHubDate(repo.pushedAt ?? repo.updatedAt)
        return GitHubInsightKBEntry(
            id: UUID(),
            repoURL: repo.htmlUrl,
            fullName: repo.fullName,
            description: repo.description ?? "",
            stars: repo.stargazersCount,
            language: repo.language,
            topics: repo.topics ?? [],
            lastPushedAt: pushedAt,
            relevanceScore: score,
            keyInsights: keyInsights(repo: repo, profile: profile),
            syncedAt: Date()
        )
    }

    /// 为仓库和项目画像计算启发式相关性分数。
    private func relevanceScore(repo: GitHubRepository, profile: GitHubInsightProjectProfile) -> Double {
        let languageMatch = repo.language?.caseInsensitiveCompare(profile.primaryLanguage ?? "") == .orderedSame ? 1.0 : 0.0
        let text = ([repo.fullName, repo.description ?? ""] + (repo.topics ?? [])).joined(separator: " ").lowercased()
        let keywords = Set((profile.frameworks + profile.dependencies + profile.keywords).map { $0.lowercased() })
        let overlap = keywords.isEmpty ? 0.0 : Double(keywords.filter { text.contains($0) }.count) / Double(max(keywords.count, 1))
        let starsScore = min(log10(Double(max(repo.stargazersCount, 1))) / 5.0, 1.0)
        let recencyScore = recencyScore(date: parseGitHubDate(repo.pushedAt ?? repo.updatedAt))

        return languageMatch * 0.35 + overlap * 0.25 + starsScore * 0.20 + recencyScore * 0.20
    }

    /// 构建简短可读信号，用于说明仓库为什么被选中。
    private func keyInsights(
        repo: GitHubRepository,
        profile: GitHubInsightProjectProfile
    ) -> [String] {
        var insights: [String] = []
        insights.append("Related GitHub repository discovered from this project's language, frameworks, dependencies, or keywords.")

        if let language = repo.language, language == profile.primaryLanguage {
            insights.append("Uses the same primary language: \(language).")
        }
        if repo.stargazersCount >= 1000 {
            insights.append("Strong community signal with \(repo.stargazersCount) stars.")
        }
        if let topics = repo.topics, !topics.isEmpty {
            insights.append("Topics: \(topics.prefix(5).joined(separator: ", ")).")
        }
        return insights
    }

    /// 使用最后 push 或更新时间评估仓库新鲜度。
    private func recencyScore(date: Date?) -> Double {
        guard let date else { return 0.3 }
        let ageDays = max(Date().timeIntervalSince(date) / 86_400, 0)
        if ageDays < 30 { return 1.0 }
        if ageDays < 180 { return 0.8 }
        if ageDays < 365 { return 0.6 }
        if ageDays < 730 { return 0.4 }
        return 0.2
    }

    /// 解析 GitHub API 返回的 ISO-8601 日期。
    private func parseGitHubDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    /// 判断两个依赖名称在标准化后是否指向同一个包。
    private func sameDependency(_ lhs: String, _ rhs: String) -> Bool {
        normalizeDependency(lhs) == normalizeDependency(rhs)
    }

    /// 标准化包名和仓库名，用于依赖比较。
    private func normalizeDependency(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ".git", with: "")
            .split(separator: "/")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "") ?? value.lowercased()
    }
}
