import SwiftUI
import Testing
@testable import ProviderOnboarding

@MainActor
@Test("注册同 ID 页面会替换原项并保持列表顺序")
func registeringPageReplacesMatchingID() {
    let provider = DefaultOnboardingProviding()
    let first = OnboardingPageItem(id: "first", title: "First") { Text("first") }
    let second = OnboardingPageItem(id: "second", title: "Second") { Text("second") }
    let replacement = OnboardingPageItem(id: "first", title: "Updated") { Text("updated") }

    provider.register(first)
    provider.register(second)
    provider.register(replacement)

    #expect(provider.allPages.map(\.id) == ["second", "first"])
    #expect(provider.allPages.last?.title == "Updated")
}

@MainActor
@Test("页面注册和实际删除发通知，不存在的 ID 不发通知")
func pageChangesNotifyObserversOnlyWhenStateChanges() {
    let provider = DefaultOnboardingProviding()
    var events: [String] = []
    let observer = provider.addObserver { event in
        if case .pagesChanged = event { events.append("pages") }
    }
    defer { observer.cancel() }

    provider.unregister(id: "missing")
    provider.register(OnboardingPageItem(id: "one", title: "One") { Text("one") })
    provider.unregister(id: "missing")
    provider.unregister(id: "one")
    provider.unregister(id: "one")

    #expect(events == ["pages", "pages"])
    #expect(provider.allPages.isEmpty)
}

@MainActor
@Test("show 和 dismiss 仅在可见状态变化时通知")
func presentationTransitionsAreIdempotent() {
    let provider = DefaultOnboardingProviding()
    var events: [Bool] = []
    let observer = provider.addObserver { event in
        if case .presentationChanged(let isPresented) = event {
            events.append(isPresented)
        }
    }
    defer { observer.cancel() }

    provider.dismiss()
    provider.show()
    provider.show()
    provider.dismiss()
    provider.dismiss()

    #expect(events == [true, false])
    #expect(!provider.isPresented)
}

@MainActor
@Test("replay 每次清除完成状态并通知首屏重新开始")
func replayAlwaysCallsHandlerAndPublishesPresentation() {
    var replayCount = 0
    let provider = DefaultOnboardingProviding(onReplay: { replayCount += 1 })
    var events: [Bool] = []
    let observer = provider.addObserver { event in
        if case .presentationChanged(let isPresented) = event {
            events.append(isPresented)
        }
    }
    defer { observer.cancel() }

    provider.replay()
    provider.replay()
    provider.dismiss()
    provider.replay()

    #expect(replayCount == 3)
    #expect(events == [true, true, false, true])
    #expect(provider.isPresented)
}

@MainActor
@Test("取消观察句柄后不再收到事件")
func cancelledObserverStopsReceivingEvents() {
    let provider = DefaultOnboardingProviding()
    var eventCount = 0
    let observer = provider.addObserver { _ in eventCount += 1 }

    provider.register(OnboardingPageItem(id: "one", title: "One") { Text("one") })
    observer.cancel()
    observer.cancel()
    provider.show()
    provider.unregister(id: "one")

    #expect(eventCount == 1)
}

@MainActor
@Test("页面内容闭包仅在 makeView 被请求时构建")
func pageViewIsCreatedOnDemand() {
    var wasCreated = false
    let page = OnboardingPageItem(id: "one", title: "One") {
        wasCreated = true
        return Text("one")
    }

    #expect(page.id == "one")
    #expect(page.title == "One")
    #expect(!wasCreated)

    _ = page.makeView()

    #expect(wasCreated)
}
