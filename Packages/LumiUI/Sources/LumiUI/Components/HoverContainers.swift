import AppKit
import Combine
import SwiftUI

@MainActor
public final class HoverCoordinator: ObservableObject {
    public static let shared = HoverCoordinator()

    @Published public var visibleID: String?

    private var hideWorkItem: DispatchWorkItem?

    public func onHover(id: String, isHovering: Bool) {
        if isHovering {
            hideWorkItem?.cancel()
            hideWorkItem = nil

            if visibleID != id {
                visibleID = id
            }
        } else if visibleID == id {
            let item = DispatchWorkItem { [weak self] in
                if self?.visibleID == id {
                    self?.visibleID = nil
                }
            }
            hideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }
    }

    public func close(id: String) {
        if visibleID == id {
            visibleID = nil
        }
    }

    public func closeAll() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        visibleID = nil
    }

    public func open(id: String) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        visibleID = id
    }
}

public struct StatusBarHoverContainer<Content: View, Detail: View>: View {
    let detailView: Detail?
    let content: Content
    let popoverWidth: CGFloat
    let id: String
    let arrowEdge: Edge

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @State private var isPresented = false
    @State private var isHovering = false

    public init(
        detailView: Detail,
        popoverWidth: CGFloat = 480,
        id: String = UUID().uuidString,
        arrowEdge: Edge = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.detailView = detailView
        self.content = content()
        self.popoverWidth = popoverWidth
        self.id = id
        self.arrowEdge = arrowEdge
    }

    public init(
        id: String = UUID().uuidString,
        @ViewBuilder content: () -> Content
    ) where Detail == EmptyView {
        self.detailView = nil
        self.content = content()
        self.popoverWidth = 480
        self.id = id
        self.arrowEdge = .top
    }

    public var body: some View {
        baseContent
    }

    @ViewBuilder
    private var baseContent: some View {
        let view = content
            .background(hoverBackground)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                guard detailView != nil else { return }

                withAnimation(.easeOut(duration: 0.15)) {
                    if isPresented {
                        isPresented = false
                        coordinator.close(id: self.id)
                    } else {
                        coordinator.closeAll()
                        isPresented = true
                        coordinator.open(id: self.id)
                    }
                }
            }

        if detailView != nil {
            view.popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                popoverContent
            }
        } else {
            view
        }
    }

    private var hoverBackground: some View {
        ZStack {
            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.25))
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let detailView {
            detailView
                .onHover { hovering in
                    if hovering {
                        coordinator.open(id: self.id)
                    }
                }
                .padding(24)
                .frame(width: popoverWidth)
                .background(Material.regularMaterial)
        }
    }
}

public extension StatusBarHoverContainer {
    static func withTextDetail<C: View>(
        _ detailText: String,
        title: String? = nil,
        id: String = UUID().uuidString,
        @ViewBuilder content: @escaping () -> C
    ) -> StatusBarHoverContainer<C, AnyView> {
        let detailContent = AnyView(
            VStack(alignment: .leading, spacing: 8) {
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                Text(detailText)
                    .font(.system(size: 12))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .textSelection(.enabled)
            }
        )

        return StatusBarHoverContainer<C, AnyView>(
            detailView: detailContent,
            id: id,
            content: content
        )
    }
}

public struct HoverableContainerView<Content: View, Detail: View>: View {
    let detailView: Detail
    let content: Content
    let id: String

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @State private var isPresented = false

    public init(detailView: Detail, id: String = UUID().uuidString, @ViewBuilder content: () -> Content) {
        self.detailView = detailView
        self.id = id
        self.content = content()
    }

    public var body: some View {
        content
            .background(background(isHovering: isPresented))
            .animation(.easeInOut(duration: 0.2), value: isPresented)
            .onHover { hovering in
                coordinator.onHover(id: self.id, isHovering: hovering)
            }
            .popover(isPresented: $isPresented, arrowEdge: .leading) {
                detailView
                    .background(SpaceAwarePopoverWindowConfigurator())
                    .onHover { hovering in
                        coordinator.onHover(id: self.id, isHovering: hovering)
                    }
                    .padding(12)
                    .frame(width: 600)
            }
            .onReceive(coordinator.$visibleID) { visibleID in
                let shouldShow = visibleID == self.id
                if isPresented != shouldShow {
                    isPresented = shouldShow
                }
            }
            .onChange(of: isPresented) { oldValue, newValue in
                guard oldValue != newValue else { return }

                if !newValue && coordinator.visibleID == self.id {
                    coordinator.close(id: self.id)
                }
            }
    }

    private func background(isHovering: Bool) -> some View {
        ZStack {
            if isHovering {
                Rectangle()
                    .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.2))
            } else {
                EmptyView()
            }
        }
    }
}

private struct SpaceAwarePopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfigView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfigView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }
}
