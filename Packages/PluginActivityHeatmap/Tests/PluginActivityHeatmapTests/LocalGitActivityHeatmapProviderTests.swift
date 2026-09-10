import Foundation
import GitPlugin
import Testing
@testable import PluginActivityHeatmap

@Suite("LocalGitActivityHeatmapProvider")
struct LocalGitActivityHeatmapProviderTests {
    @Test("groups commit logs by the local calendar day")
    func groupsCommitsByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let formatter = ISO8601DateFormatter()
        let commits = [
            makeCommit(hash: "1", date: formatter.string(from: firstDay), message: "one"),
            makeCommit(hash: "2", date: formatter.string(from: firstDay.addingTimeInterval(3_600)), message: "two"),
            makeCommit(hash: "3", date: formatter.string(from: secondDay), message: "three"),
        ]

        let snapshot = LocalGitActivityHeatmapProvider.makeSnapshot(
            repositoryPath: "/tmp/project",
            commits: commits,
            calendar: calendar,
            now: secondDay
        )

        #expect(snapshot.days.map { $0.commitCount } == [2, 1])
    }

    private func makeCommit(hash: String, date: String, message: String) -> GitCommitLog {
        let data = "{\"hash\":\"\(hash)\",\"author\":\"A\",\"email\":\"a@example.com\",\"date\":\"\(date)\",\"message\":\"\(message)\"}".data(using: .utf8)!
        return try! JSONDecoder().decode(GitCommitLog.self, from: data)
    }
}
