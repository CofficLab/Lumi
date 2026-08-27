import Foundation
import Testing
@testable import ProviderWebServer

/// DefaultWebServerProviding 内存默认实现的基础验证。
@Suite("DefaultWebServerProviding")
@MainActor
struct DefaultWebServerProvidingTests {

    @Test("运行状态和路由变化会发出语义事件")
    func emitsServerEvents() async throws {
        final class EventBox: @unchecked Sendable {
            private let lock = NSLock()
            private var events: [WebServerEvent] = []

            func append(_ event: WebServerEvent) {
                lock.lock()
                events.append(event)
                lock.unlock()
            }

            func contains(_ event: WebServerEvent) -> Bool {
                lock.lock()
                defer { lock.unlock() }
                return events.contains(event)
            }
        }

        let eventBox = EventBox()
        let server = DefaultWebServerProviding(port: 9999)
        let token = server.addWebServerObserver { eventBox.append($0) }

        server.register([], forPlugin: "theme")
        try await server.start()
        await server.stop()

        #expect(eventBox.contains(.routesChanged(pluginID: "theme")))
        #expect(eventBox.contains(.started(port: 9999)))
        #expect(eventBox.contains(.stopped))
        token.cancel()
    }

    @Test("命中路由后发出包含归属插件的活动事件")
    func emitsActivityAfterHandlingRoute() async throws {
        final class ActivityBox: @unchecked Sendable {
            private let lock = NSLock()
            private var value: WebRequestActivity?
            func set(_ activity: WebRequestActivity) { lock.lock(); value = activity; lock.unlock() }
            func get() -> WebRequestActivity? { lock.lock(); defer { lock.unlock() }; return value }
        }
        let box = ActivityBox()
        let server = DefaultWebServerProviding(onActivity: { box.set($0) })
        server.register([
            WebRoute(id: "theme.switch", method: .post, path: "/api/theme/:id", description: "Switch theme") { _ in
                .text("ok", statusCode: 201)
            }
        ], forPlugin: "theme")

        _ = try await server.handle(WebRouteRequest(method: .post, path: "/api/theme/dark"))
        let activity = try #require(box.get())
        #expect(activity.pluginID == "theme")
        #expect(activity.statusCode == 201)
        #expect(activity.isMutation)
    }

    @Test("按插件注册/替换/注销路由")
    func registerReplaceUnregister() async throws {
        let server = DefaultWebServerProviding()
        let routeA = WebRoute(id: "a", method: .get, path: "/a") { _ in .text("a") }
        let routeB = WebRoute(id: "b", method: .get, path: "/b") { _ in .text("b") }

        // 同一 pluginID 再次注册会整体替换旧路由
        server.register([routeA], forPlugin: "p1")
        server.register([routeB], forPlugin: "p1")

        let hitB = try await server.handle(WebRouteRequest(method: .get, path: "/b"))
        #expect(hitB.statusCode == 200)
        #expect(String(data: hitB.body, encoding: .utf8) == "b")

        // 旧路由已被替换,不再命中
        let hitA = try await server.handle(WebRouteRequest(method: .get, path: "/a"))
        #expect(hitA.statusCode == 404)

        // 空数组等效于 unregister
        server.register([], forPlugin: "p1")
        let afterUnregister = try await server.handle(WebRouteRequest(method: .get, path: "/b"))
        #expect(afterUnregister.statusCode == 404)

        server.unregister(pluginID: "p1")
    }

    @Test("匹配 :param 占位符并区分 404/405")
    func routeMatching() async throws {
        let server = DefaultWebServerProviding()
        let route = WebRoute(id: "theme.switch", method: .get, path: "/api/theme/:id", description: "Switch theme") { request in
            let id = request.pathParameters["id"] ?? "unknown"
            return try .json(["id": id])
        }
        server.register([route], forPlugin: "theme")

        // 命中 :param 占位符
        let ok = try await server.handle(WebRouteRequest(method: .get, path: "/api/theme/dark"))
        #expect(ok.statusCode == 200)
        let payload = try JSONDecoder().decode([String: String].self, from: ok.body)
        #expect(payload["id"] == "dark")

        // 路径不存在 -> 404
        let missing = try await server.handle(WebRouteRequest(method: .get, path: "/api/unknown"))
        #expect(missing.statusCode == 404)

        // 路径存在但方法不匹配 -> 405
        let wrongMethod = try await server.handle(WebRouteRequest(method: .post, path: "/api/theme/dark"))
        #expect(wrongMethod.statusCode == 405)
    }

    @Test("start/stop 状态切换且可重复调用")
    func startStop() async throws {
        let server = DefaultWebServerProviding(port: 9999)
        #expect(server.port == 9999)
        #expect(!server.isRunning)

        try await server.start()
        #expect(server.isRunning)

        // 重复 stop 是安全幂等的
        await server.stop()
        #expect(!server.isRunning)
        await server.stop()
        #expect(!server.isRunning)
    }

    @Test("可作为 any WebServerProviding 使用")
    func providerAsExistential() async throws {
        let server: any WebServerProviding = DefaultWebServerProviding()
        try await server.start()
        #expect(server.isRunning)
        await server.stop()
        #expect(!server.isRunning)
    }
}
