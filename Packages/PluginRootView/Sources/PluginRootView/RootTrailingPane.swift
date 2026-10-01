import Combine
import ProviderChatSection
import ProviderRootView
import SwiftUI

/// Lumi's ChatSection-aware specialization of the shared root pane.
@MainActor
public enum RootTrailingPaneEvent {
    case visibilityChanged(Bool)
    case widthChanged(ChatSectionWidth)
}

@MainActor
public protocol RootTrailingPaneObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class RootTrailingPane: RootViewPane {
    @Published public private(set) var width: ChatSectionWidth {
        didSet {
            guard oldValue != width else { return }
            updateDimensions(
                minWidth: width.minWidth,
                idealWidth: width.idealWidth,
                maxWidth: width.maxWidth
            )
            notify(.widthChanged(width))
        }
    }

    private var visibilityObserver: (any ChatSectionProvidingObserverHandle)?
    private var widthObserver: (any ChatSectionProvidingObserverHandle)?
    private var widthResizeHandler: (@MainActor (CGFloat) -> Void)?
    private var observers: [UUID: (RootTrailingPaneEvent) -> Void] = [:]

    public init(
        id: String,
        minWidth: CGFloat = 280,
        idealWidth: CGFloat = 320,
        maxWidth: CGFloat = .infinity,
        width: ChatSectionWidth? = nil,
        isVisible: Bool = true,
        content: AnyView
    ) {
        let resolvedWidth = width ?? ChatSectionWidth(
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth
        )
        self.width = resolvedWidth
        super.init(
            id: id,
            minWidth: resolvedWidth.minWidth,
            idealWidth: resolvedWidth.idealWidth,
            maxWidth: resolvedWidth.maxWidth,
            isVisible: isVisible,
            content: content
        )
    }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (RootTrailingPaneEvent) -> Void
    ) -> any RootTrailingPaneObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public override func visibilityDidChange(_ isVisible: Bool) {
        notify(.visibilityChanged(isVisible))
    }

    public func bindVisibility(to provider: any ChatSectionProviding) {
        visibilityObserver?.cancel()
        isVisible = provider.isVisible
        visibilityObserver = provider.addObserver { [weak self] event in
            guard case let .visibilityChanged(isVisible) = event else { return }
            self?.isVisible = isVisible
        }
    }

    public func bindWidth(
        to provider: any ChatSectionProviding,
        onResize: @escaping @MainActor (CGFloat) -> Void
    ) {
        widthObserver?.cancel()
        widthResizeHandler = onResize
        width = provider.chatSectionWidth
        widthObserver = provider.addObserver { [weak self] event in
            guard case let .widthChanged(width) = event else { return }
            self?.width = width
        }
    }

    public override func saveWidth(_ width: CGFloat) {
        widthResizeHandler?(width)
    }

    private func notify(_ event: RootTrailingPaneEvent) {
        for callback in observers.values {
            callback(event)
        }
    }

    private final class ObserverHandle: RootTrailingPaneObserverHandle {
        private let onCancel: () -> Void
        private var isCancelled = false

        init(onCancel: @escaping () -> Void) {
            self.onCancel = onCancel
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            onCancel()
        }
    }
}
