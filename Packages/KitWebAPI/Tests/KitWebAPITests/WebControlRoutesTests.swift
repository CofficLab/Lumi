import Foundation
import ProviderConversation
import ProviderMessage
import ProviderWebServer
import Testing
import KitAgentTool
@testable import KitWebAPI

// MARK: - Test Doubles

/// 测试用的会话管理实现。
///
/// 直接使用真实的 `DefaultConversationManager`（它实现了 `ConversationManaging`
/// 的全部要求），只在测试侧记录需要断言的副作用。
@MainActor
private final class StubConversationManager {
    /// 被测的真实会话管理器。
    let manager = DefaultConversationManager()

    /// 记录最近一次设置过的标题。
    var lastTitle: String?
    /// 记录被删除过的会话 ID。
    var deletedIDs: [UUID] = []

    /// 当前全部会话摘要。
    var conversations: [ConversationSummary] { manager.conversations }

    /// 当前选中的会话 ID。
    var selectedConversationID: UUID? { manager.selectedConversationID }

    /// 设置标题（用于测试前置条件）。
    func setTitle(_ title: String) {
        lastTitle = title
    }
}

/// 测试用的消息管理实现。
///
/// 直接使用真实的 `DefaultMessageManager`，避免为测试复制一套消息语义。
@MainActor
private final class StubMessageManager {
    /// 被测的真实消息管理器。
    let manager = DefaultMessageManager()

    /// 插入一条消息。
    func insert(_ message: Message, to conversationID: UUID) {
        manager.insertMessage(message, to: conversationID)
    }
}

// MARK: - Control Route Tests

@MainActor
@Suite("WebControlRoutes")
struct WebControlRoutesTests {
    /// 构造一份带会话与消息的控制面上下文。
    private func makeContext(
        conversationCount: Int = 0
    ) -> (WebControlContext, StubConversationManager, StubMessageManager) {
        let conversations = StubConversationManager()
        let messages = StubMessageManager()

        for index in 0..<conversationCount {
            let id = UUID()
            _ = try? conversations.manager.createConversation(
                title: "会话 \(index)",
                projectPath: "/tmp/project",
                providerID: nil,
                modelName: nil
            )
        }

        let context = WebControlContext(
            conversations: conversations.manager,
            messages: messages.manager
        )
        return (context, conversations, messages)
    }

    /// 构造控制面路由。
    private func makeRoutes(
        context: WebControlContext
    ) -> [WebRoute] {
        WebControlRoutes.makeRoutes(context: context) {
            WebStatusResponse.Service(
                version: "v1",
                uptime: 12,
                routeCount: 5,
                authenticationEnabled: false,
                host: "127.0.0.1",
                port: 7310
            )
        }
    }

    @Test("生成完整的控制面路由集")
    func generatesRoutes() {
        let (context, _, _) = makeContext()
        let routes = makeRoutes(context: context)

        #expect(routes.count == 10)
        #expect(routes.contains { $0.path == "/api/v1/status" && $0.method == .get })
        #expect(routes.contains { $0.path == "/api/v1/plugins" && $0.method == .get })
        #expect(routes.contains { $0.path == "/api/v1/plugins/:id/enable" && $0.method == .post })
        #expect(routes.contains { $0.path == "/api/v1/plugins/:id/disable" && $0.method == .post })
        #expect(routes.contains { $0.path == "/api/v1/conversations" && $0.method == .get })
        #expect(routes.contains { $0.path == "/api/v1/conversations/:id" && $0.method == .get })
        #expect(routes.contains { $0.path == "/api/v1/conversations/:id/messages" && $0.method == .get })
        #expect(routes.contains { $0.path == "/api/v1/conversations/:id/select" && $0.method == .post })
        #expect(routes.contains { $0.path == "/api/v1/conversations/:id/title" && $0.method == .post })
        #expect(routes.contains { $0.path == "/api/v1/conversations/:id" && $0.method == .delete })
    }

    @Test("状态端点返回服务与插件统计")
    func statusRouteReportsServiceInfo() async throws {
        let (context, _, _) = makeContext()
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/status" })

        let response = try await route.handler(WebRouteRequest(method: .get, path: "/api/v1/status"))
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Service: Decodable {
                let version: String
                let port: Int
                let routeCount: Int
                let authenticationEnabled: Bool
            }
            struct Plugins: Decodable {
                let total: Int
                let enabled: Int
            }
            let data: Payload
            struct Payload: Decodable {
                let service: Service
                let plugins: Plugins
                let toolCount: Int
            }
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        #expect(decoded.data.service.version == "v1")
        #expect(decoded.data.service.port == 7310)
        #expect(decoded.data.service.routeCount == 5)
        #expect(decoded.data.plugins.total == 0)
    }

    @Test("会话列表按分页返回")
    func conversationsRouteIsPaginated() async throws {
        let (context, _, _) = makeContext(conversationCount: 5)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations" })

        let response = try await route.handler(
            WebRouteRequest(
                method: .get,
                path: "/api/v1/conversations",
                queryParameters: ["offset": "0", "limit": "2"]
            )
        )
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Page: Decodable {
                let total: Int
                let offset: Int
                let limit: Int
                let hasMore: Bool
                let items: [Item]
                struct Item: Decodable {
                    let id: UUID
                    let title: String?
                }
            }
            let data: Page
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        #expect(decoded.data.total == 5)
        #expect(decoded.data.items.count == 2)
        #expect(decoded.data.hasMore == true)
    }

    @Test("查看不存在的会话抛出 notFound")
    func conversationDetailThrowsNotFound() async throws {
        let (context, _, _) = makeContext()
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id" })

        let missingID = UUID().uuidString
        await #expect(throws: WebAPIError.self) {
            try await route.handler(
                WebRouteRequest(
                    method: .get,
                    path: "/api/v1/conversations/\(missingID)",
                    pathParameters: ["id": missingID]
                )
            )
        }
    }

    @Test("非法会话 ID 抛出 badRequest")
    func conversationDetailRejectsInvalidID() async throws {
        let (context, _, _) = makeContext()
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id" })

        await #expect(throws: WebAPIError.self) {
            try await route.handler(
                WebRouteRequest(
                    method: .get,
                    path: "/api/v1/conversations/not-a-uuid",
                    pathParameters: ["id": "not-a-uuid"]
                )
            )
        }
    }

    @Test("切换会话会更新选中状态")
    func selectRouteUpdatesSelection() async throws {
        let (context, conversations, _) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id/select" })

        let targetID = try #require(conversations.conversations.first?.id)
        _ = try await route.handler(
            WebRouteRequest(
                method: .post,
                path: "/api/v1/conversations/\(targetID)/select",
                pathParameters: ["id": targetID.uuidString]
            )
        )

        #expect(conversations.manager.selectedConversationID == targetID)
    }

    @Test("选择不存在的会话返回 404 且保留原选中")
    func selectRouteRejectsMissingConversation() async throws {
        let (context, conversations, _) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id/select" })

        let existingID = try #require(conversations.conversations.first?.id)
        conversations.manager.selectConversation(id: existingID)

        let missingID = UUID()
        do {
            _ = try await route.handler(
                WebRouteRequest(
                    method: .post,
                    path: "/api/v1/conversations/\(missingID)/select",
                    pathParameters: ["id": missingID.uuidString]
                )
            )
            Issue.record("应当抛出 notFound")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 404)
            #expect(error.code == "not_found")
        }

        #expect(conversations.manager.selectedConversationID == existingID)
    }

    @Test("重命名会话写入新标题")
    func titleRouteRenamesConversation() async throws {
        let (context, conversations, _) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id/title" })

        let targetID = try #require(conversations.conversations.first?.id)
        let body = try JSONSerialization.data(withJSONObject: ["title": "新标题"])
        _ = try await route.handler(
            WebRouteRequest(
                method: .post,
                path: "/api/v1/conversations/\(targetID)/title",
                pathParameters: ["id": targetID.uuidString],
                body: body
            )
        )

        #expect(conversations.manager.conversations.first { $0.id == targetID }?.title == "新标题")
    }

    @Test("空白标题被拒绝")
    func titleRouteRejectsBlankTitle() async throws {
        let (context, conversations, _) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id/title" })

        let targetID = try #require(conversations.conversations.first?.id)
        let body = try JSONSerialization.data(withJSONObject: ["title": "   "])
        await #expect(throws: WebAPIError.self) {
            try await route.handler(
                WebRouteRequest(
                    method: .post,
                    path: "/api/v1/conversations/\(targetID)/title",
                    pathParameters: ["id": targetID.uuidString],
                    body: body
                )
            )
        }
    }

    @Test("删除会话生效")
    func deleteRouteRemovesConversation() async throws {
        let (context, conversations, _) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(
            routes.first { $0.path == "/api/v1/conversations/:id" && $0.method == .delete }
        )

        let targetID = try #require(conversations.conversations.first?.id)
        _ = try await route.handler(
            WebRouteRequest(
                method: .delete,
                path: "/api/v1/conversations/\(targetID)",
                pathParameters: ["id": targetID.uuidString]
            )
        )

        #expect(!conversations.manager.conversations.contains { $0.id == targetID })
    }

    @Test("会话消息端点返回消息列表")
    func messagesRouteReturnsMessages() async throws {
        let (context, conversations, messages) = makeContext(conversationCount: 1)
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations/:id/messages" })

        let targetID = try #require(conversations.conversations.first?.id)
        messages.insert(
            Message(conversationID: targetID, role: .user, content: "你好"),
            to: targetID
        )

        let response = try await route.handler(
            WebRouteRequest(
                method: .get,
                path: "/api/v1/conversations/\(targetID)/messages",
                pathParameters: ["id": targetID.uuidString]
            )
        )
        #expect(response.statusCode == 200)

        struct Envelope: Decodable {
            struct Page: Decodable {
                let total: Int
                struct Item: Decodable {
                    let role: String
                    let content: String
                }
                let items: [Item]
            }
            let data: Page
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: response.body)
        #expect(decoded.data.total == 1)
        #expect(decoded.data.items.first?.role == "user")
        #expect(decoded.data.items.first?.content == "你好")
    }

    @Test("缺少会话管理能力时返回 unavailable")
    func unavailableWithoutConversationManager() async throws {
        let context = WebControlContext()
        let routes = makeRoutes(context: context)
        let route = try #require(routes.first { $0.path == "/api/v1/conversations" })

        do {
            _ = try await route.handler(WebRouteRequest(method: .get, path: "/api/v1/conversations"))
            Issue.record("应当抛出 unavailable")
        } catch let error as WebAPIError {
            #expect(error.statusCode == 503)
            #expect(error.code == "unavailable")
        }
    }
}
