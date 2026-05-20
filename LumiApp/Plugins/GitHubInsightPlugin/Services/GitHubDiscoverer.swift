import Foundation

/// Discovers GitHub repositories related to a project's inferred technology ecosystem.
///
/// Discovery is driven by repository search queries built from frameworks,
/// dependencies, language, and README keywords. Results are scored and categorized
/// as alternatives, complementary projects, or examples.
struct GitHubInsightDiscoverer {
    /// Searches GitHub and returns the most relevant repository references for a profile.
    ///
    /// - Parameters:
    ///   - profile: Project profile used to build search queries and relevance scores.
    ///   - limitPerQuery: Maximum number of repositories requested per generated query.
    /// - Returns: Deduplicated and relevance-sorted knowledge base entries.
    func discover(profile: GitHubInsightProjectProfile, limitPerQuery: Int = 8) async throws -> [GitHubInsightKBEntry] {
        var entriesByRepo: [String: GitHubInsightKBEntry] = [:]

        for request in buildQueries(profile: profile) {
            let result = try await GitHubAPIService.shared.searchRepositories(
                query: request.query,
                perPage: limitPerQuery
            )

            for repo in result.items {
                guard repo.archived != true else { continue }
                if repo.fork == true && repo.stargazersCount < 50 { continue }
                if profile.dependencies.contains(where: { sameDependency($0, repo.name) || sameDependency($0, repo.fullName) }) {
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
            }
        }

        return entriesByRepo.values
            .sorted { lhs, rhs in
                if lhs.relevanceScore != rhs.relevanceScore { return lhs.relevanceScore > rhs.relevanceScore }
                return lhs.stars > rhs.stars
            }
            .prefix(24)
            .map { $0 }
    }

    /// Builds bounded GitHub repository search queries from the project profile.
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

    /// Converts a GitHub API repository response into a cache entry.
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

    /// Calculates a heuristic relevance score for a repository and project profile.
    private func relevanceScore(repo: GitHubRepository, profile: GitHubInsightProjectProfile) -> Double {
        let languageMatch = repo.language?.caseInsensitiveCompare(profile.primaryLanguage ?? "") == .orderedSame ? 1.0 : 0.0
        let text = ([repo.fullName, repo.description ?? ""] + (repo.topics ?? [])).joined(separator: " ").lowercased()
        let keywords = Set((profile.frameworks + profile.dependencies + profile.keywords).map { $0.lowercased() })
        let overlap = keywords.isEmpty ? 0.0 : Double(keywords.filter { text.contains($0) }.count) / Double(max(keywords.count, 1))
        let starsScore = min(log10(Double(max(repo.stargazersCount, 1))) / 5.0, 1.0)
        let recencyScore = recencyScore(date: parseGitHubDate(repo.pushedAt ?? repo.updatedAt))

        return languageMatch * 0.35 + overlap * 0.25 + starsScore * 0.20 + recencyScore * 0.20
    }

    /// Builds short human-readable signals explaining why a repository was selected.
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

    /// Scores repository freshness using the last pushed or updated timestamp.
    private func recencyScore(date: Date?) -> Double {
        guard let date else { return 0.3 }
        let ageDays = max(Date().timeIntervalSince(date) / 86_400, 0)
        if ageDays < 30 { return 1.0 }
        if ageDays < 180 { return 0.8 }
        if ageDays < 365 { return 0.6 }
        if ageDays < 730 { return 0.4 }
        return 0.2
    }

    /// Parses ISO-8601 dates returned by the GitHub API.
    private func parseGitHubDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    /// Returns whether two dependency names refer to the same package after normalization.
    private func sameDependency(_ lhs: String, _ rhs: String) -> Bool {
        normalizeDependency(lhs) == normalizeDependency(rhs)
    }

    /// Normalizes package and repository names for dependency comparison.
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
