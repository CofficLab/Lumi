import Foundation
import KitAgentTool
import ProviderConversation
import Testing
@testable import ComputerUsePlugin

/// 「Allow for This Task」会话授权不得跨重启生效（#405）。
///
/// 契约：A2 会话里点「允许」只在本会话内放行，不跨会话、**不跨重启**。
/// 但授权带 4 小时兜底 TTL 写进了 `authorization.plist`，正常退出 / 崩溃 /
/// 强退都不会清掉它；重启后重开同一会话，`hasSessionAccess` 命中旧条目，
/// `ComputerUseAccessChecker` 直接返回 `.allowed`，用户不再被询问。
///
/// 修复：插件启动（与退出）时调用 `revokeAllSessionAccess()` 清空上一轮
/// 进程遗留的会话授权。本组用例用「同一目录重开 store 实例」模拟重启，
/// 锁住三件事：
/// 1. 不清理时授权确实会跨重启存活（缺陷前提）；
/// 2. 启动清理后所有会话授权消失，且原生控制授权按设计保留；
/// 3. 清理后判定器对同一会话重新要求授权，而本轮新授予的授权仍正常放行。
@Suite("Computer Use 会话授权不跨重启")
struct ComputerUseSessionGrantRestartTests {

    private func makeStore() -> (store: ComputerUseAuthorizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseRestart-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationStore(dataDirectory: directory), directory)
    }

    private func context(_ level: AutomationLevel, _ conversationID: UUID) -> ComputerUseAccessContext {
        ComputerUseAccessContext(conversationID: conversationID, automationLevel: level)
    }

    // MARK: - 缺陷前提：不清理则授权跨重启存活

    @Test("不做启动清理时，会话授权会随 plist 跨重启存活")
    func sessionGrantSurvivesReopenWithoutStartupClear() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID)

        // 同一目录重开实例 = 重启后读回 plist。授权仍在，这正是缺陷前提。
        let reopened = ComputerUseAuthorizationStore(dataDirectory: directory)
        #expect(reopened.hasSessionAccess(
            bundleIdentifier: "com.example.editor",
            conversationID: conversationID
        ))
    }

    // MARK: - 启动清理 removes 会话授权

    @Test("启动清理清空所有会话的授权，且清理结果落盘")
    func startupClearRemovesPersistedSessionGrants() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationA = UUID()
        let conversationB = UUID()
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationA)
        store.grantSessionAccess(bundleIdentifier: "com.example.terminal", conversationID: conversationA)
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationB)

        // 模拟重启：重开实例读回旧授权，再执行启动清理。
        let reopened = ComputerUseAuthorizationStore(dataDirectory: directory)
        #expect(reopened.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationA))
        reopened.revokeAllSessionAccess()

        #expect(!reopened.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationA))
        #expect(!reopened.hasSessionAccess(bundleIdentifier: "com.example.terminal", conversationID: conversationA))
        #expect(!reopened.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationB))

        // 清理必须落盘：再开一个实例同样读不到任何会话授权。
        let again = ComputerUseAuthorizationStore(dataDirectory: directory)
        #expect(!again.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationA))
        #expect(!again.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationB))
    }

    @Test("启动清理保留原生控制授权（按设计跨重启延续）")
    func startupClearPreservesNativeAuthorization() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")
        store.grantSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID)

        let reopened = ComputerUseAuthorizationStore(dataDirectory: directory)
        reopened.revokeAllSessionAccess()

        // 会话授权被清掉，原生控制授权保留。
        #expect(!reopened.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID))
        #expect(reopened.isNativeAllowed("com.example.editor"))

        // 原生授权保留也要落盘。
        let again = ComputerUseAuthorizationStore(dataDirectory: directory)
        #expect(again.isNativeAllowed("com.example.editor"))
        #expect(!again.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: conversationID))
    }

    // MARK: - 判定器端到端：重启后必须重新授权

    @Test("重启并启动清理后，判定器对同一会话重新要求授权")
    func checkerRequiresReauthorizationAfterRestart() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        let bundleID = "com.example.editor"
        store.grantSessionAccess(bundleIdentifier: bundleID, conversationID: conversationID)

        // 本轮内：A2 会话已授权，放行。
        let before = ComputerUseAccessChecker(authorization: store)
        #expect(before.outcome(
            for: bundleID, applicationName: "Editor", context: context(.build, conversationID)
        ) == .allowed)

        // 重启后读回 plist：未清理时仍会放行（缺陷）。
        let reopened = ComputerUseAuthorizationStore(dataDirectory: directory)
        let leaked = ComputerUseAccessChecker(authorization: reopened)
        #expect(leaked.outcome(
            for: bundleID, applicationName: "Editor", context: context(.build, conversationID)
        ) == .allowed)

        // 启动清理后：同一会话必须重新授权，而不是静默放行。
        reopened.revokeAllSessionAccess()
        let after = ComputerUseAccessChecker(authorization: reopened)
        #expect(after.outcome(
            for: bundleID, applicationName: "Editor", context: context(.build, conversationID)
        ) == .needsAuthorization(applicationName: "Editor", bundleIdentifier: bundleID))
    }

    @Test("启动清理后本轮新授予的会话授权仍正常放行")
    func grantsAfterStartupClearStillWorkWithinSession() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversationID = UUID()
        let bundleID = "com.example.editor"

        // 启动清理先清掉上一轮遗留，再在本轮授予新授权。
        store.revokeAllSessionAccess()
        store.grantSessionAccess(bundleIdentifier: bundleID, conversationID: conversationID)

        let checker = ComputerUseAccessChecker(authorization: store)
        #expect(checker.outcome(
            for: bundleID, applicationName: "Editor", context: context(.build, conversationID)
        ) == .allowed)
    }

    @Test("空存储上的启动清理是安全的空操作")
    func startupClearOnEmptyStoreIsSafe() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.setNativeAllowed(true, bundleIdentifier: "com.example.editor")

        store.revokeAllSessionAccess()
        store.revokeAllSessionAccess()

        #expect(!store.hasSessionAccess(bundleIdentifier: "com.example.editor", conversationID: UUID()))
        #expect(store.isNativeAllowed("com.example.editor"))
    }
}