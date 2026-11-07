import SwiftUI

@MainActor
public enum MenuBarEvent {
    case contentItemsChanged
    case popupItemsChanged
}

@MainActor
public protocol MenuBarObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public protocol MenuBarProviding: AnyObject, Sendable {
    var contentItems: [MenuBarContribution] { get }
    var popupItems: [MenuBarContribution] { get }

    @discardableResult
    func addMenuBarObserver(
        _ callback: @escaping (MenuBarEvent) -> Void
    ) -> any MenuBarObserverHandle

    func replaceContentItems(_ items: [MenuBarContribution])
    func replacePopupItems(_ items: [MenuBarContribution])
}

public extension MenuBarProviding {
    func addContent(_ contribution: MenuBarContribution) {
        guard !contentItems.contains(where: { $0.id == contribution.id }) else { return }
        replaceContentItems(contentItems + [contribution])
    }

    func addPopup(_ contribution: MenuBarContribution) {
        guard !popupItems.contains(where: { $0.id == contribution.id }) else { return }
        replacePopupItems(popupItems + [contribution])
    }

    func removeItems(ids: Set<String>) {
        if contentItems.contains(where: { ids.contains($0.id) }) {
            replaceContentItems(contentItems.filter { !ids.contains($0.id) })
        }
        if popupItems.contains(where: { ids.contains($0.id) }) {
            replacePopupItems(popupItems.filter { !ids.contains($0.id) })
        }
    }

    func removeItems(ownedBy pluginID: String) {
        if contentItems.contains(where: { $0.ownerPluginID == pluginID }) {
            replaceContentItems(contentItems.filter { $0.ownerPluginID != pluginID })
        }
        if popupItems.contains(where: { $0.ownerPluginID == pluginID }) {
            replacePopupItems(popupItems.filter { $0.ownerPluginID != pluginID })
        }
    }

    func makeContentView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                ForEach(contentItems) { contribution in
                    contribution.makeView().help(contribution.title)
                }
            }
        )
    }

    func makePopupView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                ForEach(popupItems) { contribution in
                    contribution.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        )
    }
}
