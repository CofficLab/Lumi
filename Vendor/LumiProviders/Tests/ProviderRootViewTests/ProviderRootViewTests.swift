import SwiftUI
import Testing
@testable import ProviderRootView

@Suite("ProviderRootView")
@MainActor
struct ProviderRootViewTests {
    @Test("Default provider stores only the regions an app uses")
    func storesOptionalRegions() {
        let provider = DefaultRootViewProviding()

        provider.setContentView(AnyView(Text("content")))
        provider.setToolbarView(AnyView(Text("toolbar")))

        #expect(provider.contentView != nil)
        #expect(provider.toolbarView != nil)
        #expect(provider.sidebarView == nil)
        #expect(provider.railView == nil)
    }

    @Test("Overlays are deduplicated, sorted, and removable")
    func managesOverlays() {
        let provider = DefaultRootViewProviding()
        provider.addOverlays([
            RootOverlayItem(id: "toast", order: 100) { $0 },
            RootOverlayItem(id: "search", order: 10) { $0 },
        ])

        #expect(provider.overlays.map(\.id) == ["search", "toast"])

        provider.addOverlays([
            RootOverlayItem(id: "toast", order: 200) { $0 },
        ])
        #expect(provider.overlays.count == 2)
        #expect(provider.overlays.last?.id == "toast")
        #expect(provider.overlays.last?.order == 200)

        provider.removeOverlays(ids: ["search"])
        #expect(provider.overlays.map(\.id) == ["toast"])
    }

    @Test("Observer receives contribution changes and can cancel")
    func observesChanges() {
        let provider = DefaultRootViewProviding()
        var events: [RootViewEvent] = []
        let handle = provider.addRootViewObserver { event in
            events.append(event)
        }

        provider.setContentView(AnyView(Text("content")))
        provider.setContentViewHidden(true)
        provider.setTrailingPane(RootViewPane(id: "inspector") { Text("pane") })
        #expect(events.count == 3)

        handle.cancel()
        provider.setContentView(nil)
        #expect(events.count == 3)
    }

    @Test("Root provider is usable with a content-only fallback")
    func makesFallbackRootView() {
        let provider: any RootViewProviding = DefaultRootViewProviding()
        provider.setContentView(AnyView(Text("content")))

        #expect(type(of: provider.makeRootView()) == AnyView.self)
    }

    @Test("Clearing an already absent Rail view does not re-emit railViewChanged")
    func railViewChangeIsIdempotent() {
        let provider = DefaultRootViewProviding()
        var railViewChangedCount = 0
        let handle = provider.addRootViewObserver { event in
            if case .railViewChanged = event { railViewChangedCount += 1 }
        }

        provider.setRailView(AnyView(Text("rail")))
        #expect(railViewChangedCount == 1)

        provider.setRailView(nil)
        #expect(railViewChangedCount == 2)

        // A workspace plugin (such as Browser) reacts to the removal by asking
        // for the Rail to be removed again. Re-emitting here recurses forever
        // and overflows the stack, so an unchanged removal must stay silent.
        provider.setRailView(nil)
        #expect(railViewChangedCount == 2)

        handle.cancel()
    }
}
