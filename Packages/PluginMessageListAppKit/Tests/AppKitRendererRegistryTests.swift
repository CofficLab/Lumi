import AppKit
import Foundation
import Testing
import KernelLumi
@testable import MessageListAppKitPlugin

@MainActor
struct AppKitRendererRegistryTests {
    private func registry() -> AppKitMessageRendererRegistry {
        AppKitMessageRendererRegistry(environment: .init(
            theme: AppKitMessageTheme.systemDefault(),
            mermaidCache: AppKitMermaidCache(),
            layoutCache: AppKitMessageLayoutCache(),
            outerScrollView: nil
        ))
    }

    private func row(kind: AppKitMessageRow.Kind, role: LumiChatMessageRole = .assistant) -> AppKitMessageRow {
        AppKitMessageRow(
            kind: kind,
            message: LumiChatMessage(
                conversationID: UUID(), role: role, content: "hello",
                createdAt: Date(timeIntervalSinceReferenceDate: 0)
            )
        )
    }

    @Test("注册表按语义优先级选择渲染器")
    func registryPriority() {
        let registry = registry()

        #expect(registry.renderer(for: row(kind: .status)) is AppKitStatusRenderer)
        #expect(registry.renderer(for: row(kind: .error)) is AppKitErrorRenderer)
        #expect(registry.renderer(for: row(kind: .user)) is AppKitUserRenderer)
        #expect(registry.renderer(for: row(kind: .assistant)) is AppKitAssistantRenderer)
        #expect(registry.renderer(for: row(kind: .conclusion)) is AppKitAssistantRenderer)
        #expect(registry.renderer(for: row(kind: .streaming)) is AppKitAssistantRenderer)
        #expect(registry.renderer(for: row(kind: .system)) is AppKitSystemRenderer)
        #expect(registry.renderer(for: row(kind: .fallback)) is AppKitFallbackRenderer)
    }

    @Test("相同行类型返回相同 reuseIdentifier")
    func reuseIdentifiersPerKind() {
        let registry = registry()
        let assistant = registry.renderer(for: row(kind: .assistant))
        let streaming = registry.renderer(for: row(kind: .streaming))
        #expect(assistant.reuseIdentifier == streaming.reuseIdentifier) // 共享复用池
    }

    @Test("不同行类型 reuseIdentifier 互不相同")
    func reuseIdentifiersDistinct() {
        let registry = registry()
        let ids = [
            registry.renderer(for: row(kind: .assistant)).reuseIdentifier,
            registry.renderer(for: row(kind: .user)).reuseIdentifier,
            registry.renderer(for: row(kind: .status)).reuseIdentifier,
            registry.renderer(for: row(kind: .error)).reuseIdentifier,
            registry.renderer(for: row(kind: .system)).reuseIdentifier,
        ]
        #expect(Set(ids).count == ids.count)
    }

    @Test("渲染器 make/configure/prepare 生命周期可用")
    func rendererLifecycle() {
        let registry = registry()
        let renderer = registry.renderer(for: row(kind: .assistant))
        let view = renderer.makeView()
        renderer.configure(view: view, row: row(kind: .assistant, role: .assistant))
        renderer.prepareForReuse(view: view)
        // 无崩溃即通过；高度测量确定性。
        let h1 = renderer.measure(row: row(kind: .assistant), width: 600)
        let h2 = renderer.measure(row: row(kind: .assistant), width: 600)
        #expect(h1 > 0)
        #expect(h1 == h2)
    }
}
