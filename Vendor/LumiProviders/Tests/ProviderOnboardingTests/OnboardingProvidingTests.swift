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

@MainActor
@Test("默认 Provider 没有页面且不展示")
func defaultStateIsEmptyAndDismissed() {
    let provider = DefaultOnboardingProviding()
    #expect(provider.allPages.isEmpty)
    #expect(!provider.isPresented)
}

@MainActor
@Test("按注册顺序追加多个页面")
func multiplePagesKeepRegistrationOrder() {
    let provider = DefaultOnboardingProviding()
    provider.register(OnboardingPageItem(id: "a", title: "A") { Text("a") })
    provider.register(OnboardingPageItem(id: "b", title: "B") { Text("b") })
    provider.register(OnboardingPageItem(id: "c", title: "C") { Text("c") })
    #expect(provider.allPages.map(\.id) == ["a", "b", "c"])
    #expect(provider.allPages.map(\.title) == ["A", "B", "C"])
}

@MainActor
@Test("unregister 移除指定页面并保留其余顺序")
func unregisterRemovesOnlyTargetPage() {
    let provider = DefaultOnboardingProviding()
    provider.register(OnboardingPageItem(id: "a", title: "A") { Text("a") })
    provider.register(OnboardingPageItem(id: "b", title: "B") { Text("b") })
    provider.register(OnboardingPageItem(id: "c", title: "C") { Text("c") })

    provider.unregister(id: "b")
    #expect(provider.allPages.map(\.id) == ["a", "c"])
}

@MainActor
@Test("replay 在未展示时会展示 onboarding")
func replayPresentsWhenDismissed() {
    let provider = DefaultOnboardingProviding()
    #expect(!provider.isPresented)
    provider.replay()
    #expect(provider.isPresented)
}

@MainActor
@Test("没有 onReplay 闭包时 replay 不崩溃")
func replayWithoutHandlerDoesNotCrash() {
    let provider = DefaultOnboardingProviding()
    var events: [Bool] = []
    let observer = provider.addObserver { event in
        if case .presentationChanged(let isPresented) = event {
            events.append(isPresented)
        }
    }
    defer { observer.cancel() }

    provider.replay()
    #expect(provider.isPresented)
    #expect(events == [true])
}

@MainActor
@Test("多个观察者都能收到页面和展示事件")
func multipleObserversReceiveEvents() {
    let provider = DefaultOnboardingProviding()
    var first: [OnboardingProvidingEvent] = []
    var second: [OnboardingProvidingEvent] = []
    let h1 = provider.addObserver { first.append($0) }
    let h2 = provider.addObserver { second.append($0) }

    provider.register(OnboardingPageItem(id: "one", title: "One") { Text("one") })
    provider.show()

    #expect(first.count == 2)
    #expect(second.count == 2)
    h1.cancel()
    h2.cancel()
}

@MainActor
@Test("事件按 case 分类计数")
func onboardingEventCaseClassification() {
    var pagesChangedCount = 0
    var presentTrue = 0
    var presentFalse = 0
    let provider = DefaultOnboardingProviding()
    let observer = provider.addObserver { event in
        switch event {
        case .pagesChanged: pagesChangedCount += 1
        case .presentationChanged(let isPresented):
            isPresented ? (presentTrue += 1) : (presentFalse += 1)
        }
    }
    defer { observer.cancel() }

    provider.register(OnboardingPageItem(id: "x", title: "X") { Text("x") })
    provider.show()
    provider.dismiss()

    #expect(pagesChangedCount == 1)
    #expect(presentTrue == 1)
    #expect(presentFalse == 1)
}

@MainActor
@Test("dismiss 后再 show 会重新通知展示")
func showAfterDismissNotifiesAgain() {
    let provider = DefaultOnboardingProviding()
    var events: [Bool] = []
    let observer = provider.addObserver { event in
        if case .presentationChanged(let isPresented) = event {
            events.append(isPresented)
        }
    }
    defer { observer.cancel() }

    provider.show()
    provider.dismiss()
    provider.show()

    #expect(events == [true, false, true])
    #expect(provider.isPresented)
}
