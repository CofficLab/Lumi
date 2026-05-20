import Foundation
import MagicKit

/// 发现与项目推断技术生态相关的 GitHub 仓库。
///
/// 发现过程由框架、依赖、语言和 README 关键词构建出的仓库搜索查询驱动。
/// 结果会被评分，并归类为替代方案、配套项目或示例。
struct GitHubInsightDiscoverer: SuperLog {
    /// 搜索 GitHub，并返回与项目画像最相关的仓库参考。
    ///
    /// - Parameters:
    ///   - profile: 用于构建搜索查询和相关性分数的项目画像。
    ///   - limitPerQuery: 每个生成查询请求的最大仓库数量。
    /// - Returns: 去重并按相关性排序后的知识库条目。
    func discover(profile: GitHubInsightProjectProfile, limitPerQuery: Int = 8) async throws -> [GitHubInsightKBEntry] {
        var entriesByRepo: [String: GitHubInsightKBEntry] = [:]
        let queries = buildQueries(profile: profile)

        GitHubInsightPlugin.logger.info("\(Self.t)开始 GitHub 发现：project=\(profile.projectPath)，queries=\(queries.count)，limitPerQuery=\(limitPerQuery)")

        for (index, request) in queries.enumerated() {
            GitHubInsightPlugin.logger.info("\(Self.t)请求 GitHub 仓库搜索[\(index + 1)/\(queries.count)]：type=\(request.relationType.rawValue)，query=\(request.query)")
            let result = try await GitHubAPIService.shared.searchRepositories(
                query: request.query,
                perPage: limitPerQuery
            )

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

                let entry = entry(from: repo, relationType: request.relationType, profile: profile)
                if let existing = entriesByRepo[entry.fullName] {
                    if entry.relevanceScore > existing.relevanceScore {
                        entriesByRepo[entry.fullName] = entry
                    }
                } else {
                    entriesByRepo[entry.fullName] = entry
                }
                acceptedCount += 1
            }

            GitHubInsightPlugin.logger.info("\(Self.t)GitHub 搜索完成[\(index + 1)/\(queries.count)]：返回=\(result.items.count)，接受=\(acceptedCount)，归档过滤=\(archivedCount)，低信号 fork 过滤=\(lowSignalForkCount)，已有依赖过滤=\(existingDependencyCount)，累计唯一仓库=\(entriesByRepo.count)")
        }

        let entries = entriesByRepo.values
            .sorted { lhs, rhs in
                if lhs.relevanceScore != rhs.relevanceScore { return lhs.relevanceScore > rhs.relevanceScore }
                return lhs.stars > rhs.stars
            }
            .prefix(24)
            .map { $0 }

        GitHubInsightPlugin.logger.info("\(Self.t)GitHub 发现结束：候选唯一仓库=\(entriesByRepo.count)，输出条目=\(entries.count)")
        return entries
    }

    /// 基于项目画像构建有数量上限的 GitHub 仓库搜索查询。
    private func buildQueries(profile: GitHubInsightProjectProfile) -> [(query: String, relationType: GitHubInsightRelationType)] {
        let language = profile.primaryLanguage.map { "language:\($0)" } ?? ""
        let recency = "pushed:>2024-01-01"
        let stars = "stars:>100"

        var queries: [(String, GitHubInsightRelationType)] = []
        let frameworks = Array(profile.frameworks.prefix(3))
        let dependencies = Array(profile.dependencies.prefix(4))
        let keywords = Array(profile.keywords.prefix(4))

        for framework in frameworks {
            queries.append(("\(framework) \(language) topic:example \(stars) \(recency)", .example))
            queries.append(("\(framework) \(language) best practices \(stars) \(recency)", .complementary))
        }

        for dependency in dependencies {
            queries.append(("\(dependency) alternative \(language) \(stars) \(recency)", .alternative))
        }

        let keywordQuery = (frameworks + keywords).prefix(4).joined(separator: " ")
        if !keywordQuery.isEmpty {
            queries.append(("\(keywordQuery) \(language) \(stars) \(recency)", .complementary))
        }

        if queries.isEmpty, let primaryLanguage = profile.primaryLanguage {
            queries.append(("language:\(primaryLanguage) \(stars) \(recency)", .complementary))
        }

        return Array(queries.prefix(8))
    }

    /// 将 GitHub API 仓库响应转换为缓存条目。
    private func entry(
        from repo: GitHubRepository,
        relationType: GitHubInsightRelationType,
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
            relationType: relationType,
            keyInsights: keyInsights(repo: repo, relationType: relationType, profile: profile),
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
        relationType: GitHubInsightRelationType,
        profile: GitHubInsightProjectProfile
    ) -> [String] {
        var insights: [String] = []
        switch relationType {
        case .alternative:
            insights.append("Potential alternative to a dependency in this project; verify API fit before adopting.")
        case .complementary:
            insights.append("Related project in the same ecosystem that may complement the current stack.")
        case .example:
            insights.append("Reference project or example that may show ecosystem conventions.")
        }

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
