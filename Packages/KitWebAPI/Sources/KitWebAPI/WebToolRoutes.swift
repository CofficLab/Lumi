import Foundation
import ProviderWebServer

// MARK: - Tool Invoke Request

/// `POST /api/v1/tools/:name/invoke` 的请求体。
public struct WebToolInvokeRequest: Decodable, Sendable {
    /// 工具参数。
    public let arguments: [String: JSONValue]?

    /// 会话 ID。缺省时桥接器用兜底会话。
    public let conversationID: UUID?

    public init(arguments: [String: JSONValue]? = nil, conversationID: UUID? = nil) {
        self.arguments = arguments
        self.conversationID = conversationID
    }
}

// MARK: - Tool Routes

/// 工具相关的 HTTP 路由。
///
/// 路由由桥接器生成，宿主只需把它们注册到 Web 服务。
public enum WebToolRoutes {
    /// 构造工具路由。
    ///
    /// - Parameters:
    ///   - bridge: 工具桥接器。
    ///   - prefix: 路径前缀，默认 `/api/v1/tools`。
    /// - Returns: 可直接注册的路由列表。
    public static func makeRoutes(
        bridge: WebToolBridge,
        prefix: String = "/api/v1/tools"
    ) -> [WebRoute] {
        let builder = WebRouteBuilder(prefix: "tools")
        return builder
            .get(prefix, description: "列出全部可调用的 Agent 工具及其参数 schema") { _ in
                try .api(bridge.toolDescriptors())
            }
            .get("\(prefix)/:name", description: "查看单个工具的详情与参数 schema") { request in
                let name = try request.requirePathParameter("name")
                guard let descriptor = bridge.toolDescriptor(named: name) else {
                    throw WebAPIError.notFound(message: "Tool not found: \(name)")
                }
                return try .api(descriptor)
            }
            .post("\(prefix)/:name/invoke", description: "调用指定的 Agent 工具") { request in
                let name = try request.requirePathParameter("name")
                let payload = try request.decodeBodyOrThrow(WebToolInvokeRequest.self)

                let arguments = payload.arguments?.mapValues(\.anyValue) ?? [:]
                let result = try await bridge.invoke(
                    tool: name,
                    arguments: arguments,
                    conversationID: payload.conversationID
                )
                // 工具自身返回错误时仍用 200，由 `isError` 字段表达——
                // HTTP 状态码表达「调用是否送达」，业务成败由 body 表达。
                return try .api(result)
            }
            .build()
    }
}

// MARK: - JSONValue Conversion

extension JSONValue {
    /// 还原为任意 JSON 兼容值。
    public var anyValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.anyValue)
        case .object(let values):
            return values.mapValues(\.anyValue)
        }
    }
}
