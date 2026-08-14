import Foundation

// MARK: - Route Path Matcher

/// 路由路径模板匹配器。
///
/// 把 `WebRoute.path`(如 `/api/theme/:id`)与实际请求路径(如 `/api/theme/dark`)
/// 匹配,并解析出参数。模板按 `/` 分段,支持:
///
/// - 普通字面量:`theme`
/// - 参数占位符:`:id` —— 匹配单段,结果存入 `[parameter: value]`
/// - 单段通配:`*` —— 匹配单段(不捕获)
/// - 多段通配:`**` —— 匹配剩余所有段(包括零段),且必须是模板最后一段
///
/// 该类型为纯值类型且 `Sendable`,可安全被后台请求线程并发读取。
public struct RouteMatcher: Sendable {
    /// 原始模板字符串。
    public let template: String

    private let segments: [Segment]

    private enum Segment: Sendable {
        case literal(String)
        case parameter(String)
        case wildcardOne   // *
        case wildcardRest  // **
    }

    public init(template: String) {
        self.template = template
        self.segments = Self.parse(template)
    }

    private static func parse(_ template: String) -> [Segment] {
        template
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { part in
                let s = String(part)
                if s == "**" { return .wildcardRest }
                if s == "*" { return .wildcardOne }
                if s.hasPrefix(":") { return .parameter(String(s.dropFirst())) }
                return .literal(s)
            }
    }

    /// 尝试匹配给定路径。
    ///
    /// - Parameter path: 实际请求路径(不含 query string)。
    /// - Returns: 匹配成功返回解析出的 path 参数(可能为空字典);失败返回 `nil`。
    public func match(_ path: String) -> [String: String]? {
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var parameters: [String: String] = [:]

        var i = 0  // 模板段索引
        var j = 0  // 路径段索引

        while i < segments.count {
            switch segments[i] {
            case .literal(let literal):
                guard j < pathParts.count, pathParts[j] == literal else { return nil }
                i += 1
                j += 1

            case .parameter(let name):
                guard j < pathParts.count else { return nil }
                parameters[name] = pathParts[j]
                i += 1
                j += 1

            case .wildcardOne:
                guard j < pathParts.count else { return nil }
                i += 1
                j += 1

            case .wildcardRest:
                // `**` 匹配剩余所有段(可为零段),必须是模板最后一段。
                return parameters
            }
        }

        // 模板已耗尽:路径也必须恰好耗尽才算匹配。
        return j == pathParts.count ? parameters : nil
    }
}
