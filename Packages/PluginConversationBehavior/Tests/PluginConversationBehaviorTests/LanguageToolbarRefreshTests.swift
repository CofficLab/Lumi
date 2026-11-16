import Foundation
import Testing
import SwiftUI
import AppKit
import KitLLM
import ProviderConversation
@testable import PluginConversationBehavior

/// 语言 chip 的事件驱动刷新回归（**#846**）。
///
/// `LanguageToolbarView` 动态读取选中会话的语言，但若不订阅会话事件，
/// 直接在两个已有会话间切换时宿主不会重绘，chip 与弹窗会停留在上一个
/// 会话的语言，而实际请求已用新会话的配置——显示与行为不一致。
///
/// 纯 SwiftUI `Text` 经 CoreText 图层渲染，单测里读不到 `NSTextField`，
/// 因此用「转发 + 计数」的 `ConversationManaging` 替身锁定机制：视图出现
/// （`.onAppear` 注册观察者）后，会话事件必须触发 body 重算并**重新读取**
/// `language(for:)`。没有观察者时事件不会引起重读，计数不变 → 转红。
/// 异步 settle 让出主 actor（不能用 `RunLoop.main.run` 阻塞，会饿死并行套件）。
@Suite("LanguageToolbarView 刷新（#846）")
@MainActor
struct LanguageToolbarRefreshTests {
    @Test("切换会话触发语言 chip 重读新会话语言（**回归 #846**）")
    func languageChipRereadsOnConversationSwitch() async throws {
        let inner = DefaultConversationManager()
        let a = try inner.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
        inner.setLanguage(.chinese, for: a)
        let b = try inner.createConversation(title: "B", projectPath: nil, providerID: nil, modelName: nil)
        inner.setLanguage(.english, for: b)
        inner.selectConversation(id: a)

        let spy = CountingConversationManager(inner: inner)
        let window = makeWindow()
        let host = NSHostingView(rootView: AnyView(
            LanguageToolbarView(conversations: spy).frame(width: 120, height: 40)
        ))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        await settle()

        // 视图已出现并注册观察者；记录初始渲染后的读取基线。
        let baseline = spy.languageReadCount
        #expect(baseline > 0, "前置条件：初始 body 应已读取过语言")
        #expect(spy.lastLanguageReadID == a, "初始读取的应是会话 A")

        // 不经过 New Chat、不发消息，直接切到 B（发出 .selected）。
        inner.selectConversation(id: b)
        await settle()

        #expect(spy.languageReadCount > baseline, "切换会话后必须重读语言，否则 chip 停留在 A")
        #expect(spy.lastLanguageReadID == b, "重读应取新选中会话 B 的语言")
        window.orderOut(nil)
    }

    @Test("当前会话语言改写触发 chip 重读（**回归 #846**）")
    func languageChipRereadsOnLanguageChanged() async throws {
        let inner = DefaultConversationManager()
        let a = try inner.createConversation(title: "A", projectPath: nil, providerID: nil, modelName: nil)
        inner.setLanguage(.chinese, for: a)
        inner.selectConversation(id: a)

        let spy = CountingConversationManager(inner: inner)
        let window = makeWindow()
        let host = NSHostingView(rootView: AnyView(
            LanguageToolbarView(conversations: spy).frame(width: 120, height: 40)
        ))
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        await settle()
        let baseline = spy.languageReadCount
        #expect(baseline > 0)

        // 改写当前会话语言（发出 .languageChanged）。
        inner.setLanguage(.english, for: a)
        await settle()

        #expect(spy.languageReadCount > baseline, "语言改写后必须重读，否则 chip 停留在旧值")
        window.orderOut(nil)
    }

    // MARK: - Harness

    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
    }

    private func settle() async {
        for _ in 0..<30 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// 转发到真实 `DefaultConversationManager` 的计数替身。
///
/// 只额外记录 `language(for:)` 的读取次数与最近一次读取的会话 ID，
/// 其余成员原样转发；观察者注册也转发到 inner，确保视图收到真实事件。
@MainActor
private final class CountingConversationManager: ConversationManaging {
    private let inner: DefaultConversationManager
    private(set) var languageReadCount = 0
    private(set) var lastLanguageReadID: UUID?

    init(inner: DefaultConversationManager) {
        self.inner = inner
    }

    var conversations: [ConversationSummary] { inner.conversations }
    var selectedConversationID: UUID? { inner.selectedConversationID }
    var currentTitle: String { inner.currentTitle }
    var dataDirectory: URL { inner.dataDirectory }

    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
        try inner.createConversation(title: title, projectPath: projectPath, providerID: providerID, modelName: modelName)
    }
    func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?, parentConversationID: UUID?) throws -> UUID {
        try inner.createConversation(title: title, projectPath: projectPath, providerID: providerID, modelName: modelName, parentConversationID: parentConversationID)
    }
    func selectConversation(id: UUID) { inner.selectConversation(id: id) }
    func deselectConversation() { inner.deselectConversation() }
    func deleteConversation(id: UUID) { inner.deleteConversation(id: id) }
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        inner.updateConversationTitle(title, for: conversationID)
    }
    func markConversationActive(id: UUID, messageDate: Date) { inner.markConversationActive(id: id, messageDate: messageDate) }
    func isSending(for conversationID: UUID?) -> Bool { inner.isSending(for: conversationID) }

    func providerID(for conversationID: UUID?) -> String? { inner.providerID(for: conversationID) }
    func modelName(for conversationID: UUID?) -> String? { inner.modelName(for: conversationID) }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        inner.selectProvider(id: id, model: model, for: conversationID)
    }

    var globalVerbosity: ResponseVerbosity { inner.globalVerbosity }
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) { inner.setGlobalVerbosity(verbosity) }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { inner.verbosity(for: conversationID) }
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) { inner.setVerbosity(verbosity, for: conversationID) }

    var globalReasoningEffort: ReasoningEffort? { inner.globalReasoningEffort }
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) { inner.setGlobalReasoningEffort(reasoningEffort) }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { inner.reasoningEffort(for: conversationID) }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { inner.reasoningEffortOptional(for: conversationID) }
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) { inner.setReasoningEffort(reasoningEffort, for: conversationID) }
    func clearReasoningEffort(for conversationID: UUID?) { inner.clearReasoningEffort(for: conversationID) }

    var globalAutomationLevel: AutomationLevel { inner.globalAutomationLevel }
    func setGlobalAutomationLevel(_ level: AutomationLevel) { inner.setGlobalAutomationLevel(level) }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { inner.automationLevel(for: conversationID) }
    func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) { inner.setAutomationLevel(level, for: conversationID) }

    var globalLanguage: ConversationLanguage { inner.globalLanguage }
    func setGlobalLanguage(_ language: ConversationLanguage) { inner.setGlobalLanguage(language) }
    func language(for conversationID: UUID?) -> ConversationLanguage {
        languageReadCount += 1
        lastLanguageReadID = conversationID
        return inner.language(for: conversationID)
    }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) { inner.setLanguage(language, for: conversationID) }

    @discardableResult
    func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
        inner.addSelectedConversationObserver(callback)
    }
    @discardableResult
    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        inner.addConversationObserver(callback)
    }
}