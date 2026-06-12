import AppKit
import SwiftUI
@testable import MarkdownKit

/// Shared AppKit layout measurement helpers for Markdown + List integration tests.
@MainActor
public enum MarkdownLayoutTestSupport {
    public static let defaultListFrame = CGSize(width: 340, height: 400)
    public static let defaultContentWidth: CGFloat = 300

    public static func fittingSize<V: View>(
        for view: V,
        frame: CGSize = CGSize(width: defaultContentWidth, height: 1),
        settleMilliseconds: Int = 150
    ) async throws -> CGSize {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: frame)
        if settleMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(settleMilliseconds))
        }
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    public static func chatStyleMarkdownList<Row: View>(
        preferOuterScroll: Bool,
        listFrame: CGSize = defaultListFrame,
        @ViewBuilder row: () -> Row
    ) -> some View {
        List {
            row()
                .listRowInsets(chatListRowInsets)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, preferOuterScroll)
        .frame(width: listFrame.width, height: listFrame.height)
    }

    public static var chatListRowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    }

    @ViewBuilder
    public static func chatStyleMarkdownRow(
        markdown: String,
        preferOuterScroll: Bool,
        width: CGFloat = defaultContentWidth
    ) -> some View {
        MarkdownBlockRenderer(markdown: markdown)
            .environment(\.preferOuterScroll, preferOuterScroll)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }

    public static func standaloneMarkdownHeight(
        markdown: String,
        width: CGFloat = defaultContentWidth,
        preferOuterScroll: Bool = true,
        settleMilliseconds: Int = 500
    ) async throws -> CGFloat {
        let renderer = MarkdownBlockRenderer(markdown: markdown)
            .environment(\.preferOuterScroll, preferOuterScroll)
            .frame(width: width, alignment: .leading)

        let size = try await fittingSize(
            for: renderer,
            frame: CGSize(width: width, height: 2_000),
            settleMilliseconds: settleMilliseconds
        )
        if size.height > 1 {
            return size.height
        }

        return try await waitForStableHeight(
            minimumHeight: 40,
            settleMilliseconds: settleMilliseconds
        ) {
            let hostingView = NSHostingView(rootView: renderer)
            hostingView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: 2_000))
            hostingView.layoutSubtreeIfNeeded()
            return max(hostingView.fittingSize.height, hostingView.intrinsicContentSize.height)
        }
    }

    public static func markdownCodeBlockDocumentHeightInList(
        markdown: String,
        preferOuterScroll: Bool,
        width: CGFloat = defaultContentWidth,
        settleMilliseconds: Int = 500
    ) async throws -> CGFloat {
        let list = chatStyleMarkdownList(preferOuterScroll: preferOuterScroll) {
            chatStyleMarkdownRow(
                markdown: markdown,
                preferOuterScroll: preferOuterScroll,
                width: width
            )
        }

        let hostingView = NSHostingView(rootView: list)
        hostingView.frame = CGRect(origin: .zero, size: defaultListFrame)
        _ = try await waitForListRowHeight(
            in: hostingView,
            minimumHeight: 40,
            settleMilliseconds: settleMilliseconds
        )

        if preferOuterScroll,
           let scrollView = findView(ofType: HorizontalOnlyScrollView.self, in: hostingView),
           let documentView = scrollView.documentView,
           documentView.frame.height > 1 {
            return documentView.frame.height
        }

        return listRowHeight(in: hostingView)
    }

    public static func markdownRowContentHeightInList(
        markdown: String,
        preferOuterScroll: Bool,
        width: CGFloat = defaultContentWidth,
        settleMilliseconds: Int = 500
    ) async throws -> CGFloat {
        let list = chatStyleMarkdownList(preferOuterScroll: preferOuterScroll) {
            chatStyleMarkdownRow(
                markdown: markdown,
                preferOuterScroll: preferOuterScroll,
                width: width
            )
        }

        let hostingView = NSHostingView(rootView: list)
        hostingView.frame = CGRect(origin: .zero, size: defaultListFrame)
        return try await waitForListRowHeight(
            in: hostingView,
            minimumHeight: 40,
            settleMilliseconds: settleMilliseconds
        )
    }

    /// Chat timeline-style scroll container; reliably measurable unlike SwiftUI `List` in headless tests.
    public static func markdownRowContentHeightInChatScroll(
        markdown: String,
        preferOuterScroll: Bool,
        width: CGFloat = defaultContentWidth,
        settleMilliseconds: Int = 200
    ) async throws -> CGFloat {
        let scroll = ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                chatStyleMarkdownRow(
                    markdown: markdown,
                    preferOuterScroll: preferOuterScroll,
                    width: width
                )
            }
            .padding(16)
        }
        .environment(\.preferOuterScroll, preferOuterScroll)
        .frame(width: defaultListFrame.width, height: defaultListFrame.height)

        return try await fittingSize(
            for: scroll,
            frame: defaultListFrame,
            settleMilliseconds: settleMilliseconds
        ).height
    }

    public static func horizontalScrollViewDocumentSize<V: View>(
        for content: V,
        width: CGFloat,
        clipHeight: CGFloat = 50,
        settleMilliseconds: Int = 200
    ) async throws -> CGSize {
        let scrollView = HorizontalScrollView { content }
        let hostingView = NSHostingView(rootView: scrollView.frame(width: width))
        hostingView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: clipHeight))
        try await Task.sleep(for: .milliseconds(settleMilliseconds))
        hostingView.layoutSubtreeIfNeeded()

        guard let horizontalScrollView = findView(ofType: HorizontalOnlyScrollView.self, in: hostingView) else {
            throw LayoutTestError.viewNotFound
        }
        return horizontalScrollView.documentView?.frame.size ?? .zero
    }

    public static func findView<T: NSView>(ofType type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = findView(ofType: type, in: subview) { return found }
        }
        return nil
    }

    private static func listRowHeight(in hostingView: NSView) -> CGFloat {
        var candidates: [CGFloat] = []

        if let tableView = findView(ofType: NSTableView.self, in: hostingView),
           tableView.numberOfRows > 0 {
            let rowIndexes = IndexSet(integersIn: 0..<tableView.numberOfRows)
            tableView.noteHeightOfRows(withIndexesChanged: rowIndexes)
            tableView.layoutSubtreeIfNeeded()
            candidates.append(contentsOf: (0..<tableView.numberOfRows).map { tableView.rect(ofRow: $0).height })
        }

        let documentHeight = preferOuterScrollDocumentHeight(in: hostingView)
        if documentHeight > 1 {
            candidates.append(documentHeight)
        }

        let nestedHostingHeight = largestHostingViewHeight(in: hostingView, excluding: hostingView)
        if nestedHostingHeight > 1 {
            candidates.append(nestedHostingHeight)
        }

        return candidates.max() ?? 0
    }

    private static func preferOuterScrollDocumentHeight(in view: NSView) -> CGFloat {
        guard let scrollView = findView(ofType: HorizontalOnlyScrollView.self, in: view),
              let documentView = scrollView.documentView else {
            return 0
        }
        return documentView.frame.height
    }

    private static func waitForListRowHeight(
        in hostingView: NSView,
        minimumHeight: CGFloat,
        settleMilliseconds: Int
    ) async throws -> CGFloat {
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        hostingView.needsLayout = true

        if settleMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(settleMilliseconds))
        }

        var lastHeight: CGFloat = 0
        for _ in 0..<12 {
            if let tableView = findView(ofType: NSTableView.self, in: hostingView),
               tableView.numberOfRows > 0 {
                tableView.scrollRowToVisible(0)
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: 0))
            }
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()

            let height = listRowHeight(in: hostingView)
            if height >= minimumHeight, abs(height - lastHeight) < 2 {
                window.orderOut(nil)
                return height
            }
            lastHeight = height
            try await Task.sleep(for: .milliseconds(100))
        }

        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        let height = listRowHeight(in: hostingView)
        window.orderOut(nil)
        return height
    }

    private static func largestHostingViewHeight(in view: NSView, excluding excluded: NSView) -> CGFloat {
        var maxHeight: CGFloat = 0
        if view !== excluded, isHostingView(view) {
            maxHeight = max(maxHeight, view.frame.height)
        }

        for subview in view.subviews {
            maxHeight = max(maxHeight, largestHostingViewHeight(in: subview, excluding: excluded))
        }
        return maxHeight
    }

    private static func isHostingView(_ view: NSView) -> Bool {
        String(describing: type(of: view)).hasPrefix("NSHostingView")
    }

    private static func waitForStableHeight(
        minimumHeight: CGFloat,
        settleMilliseconds: Int,
        measure: () -> CGFloat
    ) async throws -> CGFloat {
        if settleMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(settleMilliseconds))
        }

        var lastHeight: CGFloat = 0
        for _ in 0..<12 {
            let height = measure()
            if height >= minimumHeight, abs(height - lastHeight) < 2 {
                return height
            }
            lastHeight = height
            try await Task.sleep(for: .milliseconds(100))
        }

        return measure()
    }

    public enum LayoutTestError: Error {
        case viewNotFound
    }
}
