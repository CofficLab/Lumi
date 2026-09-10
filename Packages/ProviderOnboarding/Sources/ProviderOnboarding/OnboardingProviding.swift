import Foundation
import SwiftUI

public struct OnboardingPageItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public enum OnboardingProvidingEvent {
    case pagesChanged
    case presentationChanged(isPresented: Bool)
}

@MainActor
public protocol OnboardingObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public protocol OnboardingProviding: AnyObject {
    var allPages: [OnboardingPageItem] { get }
    var isPresented: Bool { get }
    func register(_ page: OnboardingPageItem)
    func unregister(id: String)
    func show()
    /// Clears the persisted completion state through the owning implementation
    /// and presents onboarding from the first page again.
    func replay()
    func dismiss()

    @discardableResult
    func addObserver(_ callback: @escaping (OnboardingProvidingEvent) -> Void) -> any OnboardingObserverHandle
}

@MainActor
public final class DefaultOnboardingProviding: OnboardingProviding {
    public private(set) var allPages: [OnboardingPageItem] = []
    public private(set) var isPresented = false
    private let replayHandler: (@MainActor () -> Void)?
    private var observers: [WeakObserver] = []

    public init(onReplay: (@MainActor () -> Void)? = nil) {
        replayHandler = onReplay
    }

    public func register(_ page: OnboardingPageItem) {
        allPages.removeAll { $0.id == page.id }
        allPages.append(page)
        notify(.pagesChanged)
    }

    public func unregister(id: String) {
        let oldCount = allPages.count
        allPages.removeAll { $0.id == id }
        if allPages.count != oldCount {
            notify(.pagesChanged)
        }
    }

    public func show() {
        guard !isPresented else { return }
        isPresented = true
        notify(.presentationChanged(isPresented: true))
    }

    public func replay() {
        replayHandler?()
        if !isPresented {
            isPresented = true
        }
        // Always notify so an already visible onboarding resets to page one.
        notify(.presentationChanged(isPresented: true))
    }

    public func dismiss() {
        guard isPresented else { return }
        isPresented = false
        notify(.presentationChanged(isPresented: false))
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (OnboardingProvidingEvent) -> Void) -> any OnboardingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: OnboardingProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        for observer in observers {
            observer.observer?.invoke(event)
        }
    }

    private final class Observer: OnboardingObserverHandle {
        private weak var owner: DefaultOnboardingProviding?
        private let callback: (OnboardingProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultOnboardingProviding, callback: @escaping (OnboardingProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: OnboardingProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}
