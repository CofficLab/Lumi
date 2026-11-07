#if os(macOS)
import AppKit
import SwiftUI

public enum MenuBarPopoverSizing {
    case intrinsic
    case fixedSize(NSSize)
    case fixedWidth(CGFloat, maximumHeight: CGFloat)
}

public struct MenuBarHostConfiguration {
    public var statusViewHeight: CGFloat
    public var popoverSizing: MenuBarPopoverSizing
    public var accessibilityIdentifier: String?
    public var accessibilityLabel: String?
    public var activatesApplication: Bool

    public init(
        statusViewHeight: CGFloat = 22,
        popoverSizing: MenuBarPopoverSizing = .intrinsic,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil,
        activatesApplication: Bool = false
    ) {
        self.statusViewHeight = statusViewHeight
        self.popoverSizing = popoverSizing
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
        self.activatesApplication = activatesApplication
    }
}

@MainActor
public final class MenuBarHost: NSObject {
    private var configuration = MenuBarHostConfiguration()
    private var popoverViewFactory: (() -> AnyView)?
    private(set) var statusItem: NSStatusItem?
    private(set) var statusHostingView: NSHostingView<AnyView>?
    private(set) var popover: NSPopover?

    public var isInstalled: Bool { statusItem != nil }
    public var isPopoverShown: Bool { popover?.isShown ?? false }

    public func install(
        statusView: AnyView,
        configuration: MenuBarHostConfiguration = MenuBarHostConfiguration(),
        popoverView: @escaping @MainActor () -> AnyView
    ) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            return
        }

        self.configuration = configuration
        self.popoverViewFactory = popoverView

        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.setAccessibilityIdentifier(configuration.accessibilityIdentifier)
        button.setAccessibilityLabel(configuration.accessibilityLabel)

        let hostingView = MenuBarStatusHostingView(rootView: statusView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hostingView.heightAnchor.constraint(equalToConstant: configuration.statusViewHeight),
        ])

        statusItem = item
        statusHostingView = hostingView
    }

    @objc public func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = makePopoverIfNeeded() else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            updatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            if configuration.activatesApplication {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    public func closePopover() {
        popover?.performClose(nil)
    }

    public func cleanup() {
        closePopover()
        popover = nil
        popoverViewFactory = nil
        statusHostingView = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @discardableResult
    func makePopoverIfNeeded() -> NSPopover? {
        if let popover { return popover }
        guard let popoverViewFactory else { return nil }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: popoverViewFactory())
        self.popover = popover
        updatePopoverSize()
        return popover
    }

    func updatePopoverSize() {
        guard let popover else { return }
        switch configuration.popoverSizing {
        case .intrinsic:
            break
        case .fixedSize(let size):
            popover.contentSize = size
        case .fixedWidth(let width, let maximumHeight):
            let fittingHeight = popover.contentViewController?.view.fittingSize.height ?? 0
            popover.contentSize = NSSize(width: width, height: min(fittingHeight, maximumHeight))
        }
    }
}

private final class MenuBarStatusHostingView: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
#endif
