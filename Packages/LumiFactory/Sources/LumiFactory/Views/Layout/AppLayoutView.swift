import AppKit
import LumiKernel
import LumiUI
import SwiftUI

/// 应用主布局
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel
    private let layoutManager: (any WorkspaceProviding)?

    @State private var isRailVisible: Bool = true
    @State private var isContentVisible: Bool = true
    @State private var isChatVisible: Bool = true
    @State private var isRailDividerHovered: Bool = false

    init(kernel: LumiKernel) {
        self.kernel = kernel
        self.layoutManager = kernel.workspace
    }

    var body: some View {
        if let layoutManager {
            mainLayout(layoutManager)
        } else {
            ErrorView(error: LumiKernelError.serviceNotAvailable(service: "LayoutManager"))
        }
    }

    // MARK: - Main Layout

    @ViewBuilder
    private func mainLayout(_ layoutManager: any WorkspaceProviding) -> some View {
        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(kernel: kernel)
                    .frame(maxHeight: .infinity)
                AppDivider(.vertical)

                Group {
                    if layoutManager.activeViewContainerID != nil {
                        splitLayout(layoutManager)
                    } else {
                        WelcomeView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            StatusBar(kernel: kernel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .environmentObject(AppThemeVM.shared)
        .ignoresSafeArea()
        .onRailVisibleDidChange { visible in
            isRailVisible = visible
        }
        .onChatSectionVisibleDidChange { visible in
            isChatVisible = visible
        }
        .onAppear {
            isRailVisible = layoutManager.isRailVisible
            isContentVisible = layoutManager.isContentVisible
            isChatVisible = layoutManager.isChatVisible
        }
    }

    // MARK: - Split Layout

    private func showRail(for layoutManager: any WorkspaceProviding) -> Bool {
        isRailVisible && layoutManager.activeViewContainerID != nil
    }

    private func showChat(for layoutManager: any WorkspaceProviding) -> Bool {
        isChatVisible && layoutManager.activeViewContainerID != nil
    }

    @ViewBuilder
    private func splitLayout(_ layoutManager: any WorkspaceProviding) -> some View {
        if showRail(for: layoutManager) {
            HSplitView {
                RailView(kernel: kernel)
                    .frame(minWidth: 180, idealWidth: 240, maxWidth: 400)
                    .background(
                        SplitDividerHoverCoordinator(
                            cursor: .resizeLeftRight,
                            isHovered: $isRailDividerHovered
                        )
                    )
                    .overlay(alignment: .trailing) {
                        ZStack(alignment: .trailing) {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(isRailDividerHovered ? 0.22 : 0.14)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .allowsHitTesting(false)

                            Rectangle()
                                .fill(theme.divider)
                                .frame(width: isRailDividerHovered ? 2 : 1)
                                .allowsHitTesting(false)

                        }
                        .frame(width: 8)
                    }
                mainSplitContent(layoutManager)
            }
        } else {
            mainSplitContent(layoutManager)
        }
    }

    @ViewBuilder
    private func mainSplitContent(_ layoutManager: any WorkspaceProviding) -> some View {
        if showChat(for: layoutManager) {
            HSplitView {
                PanelView(kernel: kernel, layoutManager: layoutManager)
                    .frame(minWidth: 280, maxWidth: .infinity)
                ChatView(kernel: kernel)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: .infinity)
            }
        } else {
            PanelView(kernel: kernel, layoutManager: layoutManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SplitDividerHoverCoordinator: NSViewRepresentable {
    let cursor: NSCursor
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> SplitDividerHoverCoordinatorView {
        let view = SplitDividerHoverCoordinatorView(cursor: cursor)
        view.onHoverChanged = { hovering in
            isHovered = hovering
        }
        return view
    }

    func updateNSView(_ nsView: SplitDividerHoverCoordinatorView, context: Context) {
        nsView.cursor = cursor
        nsView.onHoverChanged = { hovering in
            isHovered = hovering
        }
        nsView.attachToSplitViewIfPossible()
    }

    static func dismantleNSView(_ nsView: SplitDividerHoverCoordinatorView, coordinator: ()) {
        nsView.detach()
    }
}

@MainActor
private final class SplitDividerHoverCoordinatorView: NSView {
    var cursor: NSCursor
    var onHoverChanged: ((Bool) -> Void)?

    private weak var splitView: NSSplitView?
    private var trackingArea: NSTrackingArea?
    private var resizeObserver: NSObjectProtocol?

    init(cursor: NSCursor) {
        self.cursor = cursor
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachToSplitViewIfPossible()
    }

    func attachToSplitViewIfPossible() {
        guard window != nil else { return }
        guard let resolvedSplitView = enclosingSplitView() else {
            DispatchQueue.main.async { [weak self] in
                self?.attachToSplitViewIfPossible()
            }
            return
        }

        guard splitView !== resolvedSplitView else {
            refreshTrackingArea()
            return
        }

        detach()
        splitView = resolvedSplitView
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: resolvedSplitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTrackingArea()
            }
        }
        refreshTrackingArea()
    }

    func detach() {
        onHoverChanged?(false)
        if let trackingArea, let splitView {
            splitView.removeTrackingArea(trackingArea)
        }
        trackingArea = nil
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        resizeObserver = nil
        splitView = nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
        cursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        cursor.set()
    }

    private func refreshTrackingArea() {
        guard let splitView else { return }
        if let trackingArea {
            splitView.removeTrackingArea(trackingArea)
        }

        guard let firstPane = splitView.arrangedSubviews.first else { return }
        let dividerRect: NSRect
        if splitView.isVertical {
            dividerRect = NSRect(
                x: firstPane.frame.maxX,
                y: splitView.bounds.minY,
                width: splitView.dividerThickness,
                height: splitView.bounds.height
            )
        } else {
            dividerRect = NSRect(
                x: splitView.bounds.minX,
                y: firstPane.frame.maxY,
                width: splitView.bounds.width,
                height: splitView.dividerThickness
            )
        }
        let newTrackingArea = NSTrackingArea(
            rect: dividerRect,
            options: [.activeInKeyWindow, .cursorUpdate, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        splitView.addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
    }

    private func enclosingSplitView() -> NSSplitView? {
        var current = superview
        while let view = current {
            if let splitView = view as? NSSplitView {
                return splitView
            }
            current = view.superview
        }
        return nil
    }
}
