import Foundation

/// Go 测试输出解析器
///
/// 解析 `go test -json` 的输出行，提取结构化测试结果。
struct GoTestOutputParser {
    /// 解析后的单个测试结果
    struct TestEvent: Identifiable, Sendable {
        let id = UUID()
        /// 测试名称
        let test: String
        /// 所在包
        let `package`: String
        /// 测试状态
        let status: TestStatus
        /// 耗时（秒）
        let elapsed: Double?
        /// 输出行
        let output: String?

        /// 用于显示的行
        var displayLine: String {
            let icon: String
            switch status {
            case .pass: icon = "✅"
            case .fail: icon = "❌"
            case .skip: icon = "⏭️"
            case .run: icon = "🔄"
            }
            let elapsedStr = elapsed.map { String(format: " %.2fs", $0) } ?? ""
            return "\(icon) \(test)\(elapsedStr)"
        }
    }

    /// 测试状态
    enum TestStatus: String, Sendable {
        case pass = "pass"
        case fail = "fail"
        case skip = "skip"
        case run = "run"
    }

    /// go test -json 输出行的 JSON 结构
    private struct TestJSONLine: Decodable {
        let Action: String?
        let Package: String?
        let Test: String?
        let Elapsed: Double?
        let Output: String?
    }

    /// 解析 `go test -json` 的完整输出
    static func parse(output: String) -> [TestEvent] {
        var results: [TestEvent] = []
        let decoder = JSONDecoder()

        for line in output.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? decoder.decode(TestJSONLine.self, from: data),
                  let action = json.Action,
                  let status = TestStatus(rawValue: action)
            else { continue }

            // 只关注有测试名称的事件
            guard let test = json.Test else { continue }

            results.append(TestEvent(
                test: test,
                package: json.Package ?? "",
                status: status,
                elapsed: json.Elapsed,
                output: json.Output
            ))
        }

        return results
    }
}
