import AppKit
import KernelLumi

/// Native message-list view controller: an `NSScrollView` + view-based
/// `NSTableView` driven by immutable snapshots from the coordinator.
///
/// The controller owns exactly one coordinator instance and never touches the
/// kernel-wide observation graph. It forwards snapshot deltas to the data
/// source, keeps the scroll position stable on prepend (Task 7 refines this),
/// and manages empty/loading overlays.
@MainActor
final class AppKitMessageListViewController: NSViewController {
    let kernel: KernelLumi

    private var coordinator: AppKitMessageListCoordinator!
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var dataSource: AppKitMessageListDataSource!
    private var tableDelegate: AppKitMessageTableDelegate!
    private var scrollAnchor: AppKitScrollAnchor!
    private var rendererRegistry: AppKitMessageRendererRegistry!
    private var layoutCache = AppKitMessageLayoutCache()
    private var mermaidCache = AppKitMermaidCache()
    private var emptyStateView: AppKitEmptyStateView!
    private var loadingView: AppKitLoadingView!
    /// Bumped on effective-appearance changes so theme-sensitive layout cache
    /// keys invalidate and visible rows re-render with the new colors/fonts.
    private var themeRevision = 0

    private var currentTheme: AppKitMessageTheme {
        AppKitMessageTheme.systemDefault(revision: themeRevision)
    }

    init(kernel: KernelLumi) {
        self.kernel = kernel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = AppearanceTrackingView()
        root.onAppearanceChanged = { [weak self] in
            self?.handleAppearanceChange()
        }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        // NOTE: do NOT set translatesAutoresizingMaskIntoConstraints = false.
        // As an NSScrollView documentView, the table is frame-managed by the
        // scroll view; with Auto Layout on and no clip-view constraints its
        // frame never updates and the table stays invisible (blank area).
        // Width follows the clip view; HEIGHT stays self-managed — an
        // autoresizingMask containing .height makes NSScrollView compress the
        // table to the viewport height, clipping every row below the fold and
        // leaving a blank screen with a dead scrollbar.
        tableView.autoresizingMask = [.width]
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.floatsGroupRows = false
        // Last column fills the table width; otherwise the single column stays
        // at its initial width (often 0 when sized before layout).
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        column.resizingMask = .autoresizingMask
        column.width = 300
        column.minWidth = 80
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        self.scrollView = scrollView
        self.tableView = tableView
        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Services resolve lazily from the kernel inside the coordinator, so
        // late-registering services (kernel still booting) are still picked up.
        let dependencies = AppKitMessageListCoordinator.Dependencies(kernel: kernel)
        coordinator = AppKitMessageListCoordinator(dependencies: dependencies)

        dataSource = AppKitMessageListDataSource()
        dataSource.onLoadEarlier = { [weak self] in
            guard let self else { return }
            // Capture the top visible row before prepending, restore after the
            // snapshot lands so the viewport does not jump.
            self.scrollAnchor.captureAnchor()
            Task { @MainActor in
                await self.coordinator.loadEarlier(isAtBottom: self.scrollAnchor.isAtBottom())
                self.scrollAnchor.restoreAnchor()
            }
        }
        dataSource.attach(tableView: tableView)

        tableDelegate = AppKitMessageTableDelegate()
        tableDelegate.attach(tableView: tableView, dataSource: dataSource)

        scrollAnchor = AppKitScrollAnchor(scrollView: scrollView, tableView: tableView)
        scrollAnchor.startObserving()

        rendererRegistry = AppKitMessageRendererRegistry(environment: .init(
            theme: currentTheme,
            mermaidCache: mermaidCache,
            layoutCache: layoutCache,
            outerScrollView: scrollView,
            messageSender: kernel.messageSender
        ))
        let rendererFor: (AppKitMessageRow) -> any AppKitMessageRenderer = { [weak self] row in
            self?.rendererRegistry.renderer(for: row) ?? AppKitFallbackRenderer()
        }
        dataSource.rendererFor = rendererFor
        tableDelegate.rendererFor = rendererFor

        let emptyState = AppKitEmptyStateView()
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        emptyState.configure(
            title: LumiPluginLocalization.string("No Messages", bundle: .module),
            subtitle: LumiPluginLocalization.string("Start a new conversation", bundle: .module)
        )
        emptyState.setAccessibilityLabel(LumiPluginLocalization.string("No Messages", bundle: .module))
        view.addSubview(emptyState, positioned: .above, relativeTo: scrollView)
        NSLayoutConstraint.activate([
            emptyState.topAnchor.constraint(equalTo: view.topAnchor),
            emptyState.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        emptyStateView = emptyState

        let loading = AppKitLoadingView()
        loading.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loading, positioned: .above, relativeTo: scrollView)
        NSLayoutConstraint.activate([
            loading.topAnchor.constraint(equalTo: view.topAnchor),
            loading.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loading.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loading.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        loadingView = loading

        coordinator.onSnapshot = { [weak self] snapshot in
            self?.apply(snapshot: snapshot)
        }
        Task { [weak self] in
            await self?.coordinator.activate(
                conversationID: self?.kernel.conversations?.selectedConversationID
            )
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // Defensive: SwiftUI may not drive the frame of an NSViewController's
        // view consistently for representable bridges; keep the scroll view
        // pinned to the root bounds so the table is never laid out off-screen.
        if !view.bounds.isEmpty {
            scrollView.frame = view.bounds
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Fallback: the kernel services are almost certainly ready by the time
        // the view appears, so re-sync the selection in case the first
        // activate ran before services registered (and no change event
        // followed). No-op when nothing changed.
        let selected = kernel.conversations?.selectedConversationID
        if selected != coordinator.latestSnapshot.conversationID {
            Task { [weak self] in
                await self?.coordinator.activate(conversationID: selected)
            }
        }
        // The view is on screen now; make sure the table actually draws its
        // rows (protects against snapshots applied while off-screen).
        tableView.reloadData()
        tableView.layoutSubtreeIfNeeded()
    }

    /// Light/dark (or accent) appearance changed: bump the theme revision,
    /// invalidate theme-sensitive layout cache entries, and re-render the
    /// visible rows with the new colors/fonts.
    private func handleAppearanceChange() {
        themeRevision += 1
        layoutCache.invalidate(themeRevision: themeRevision - 1)
        rendererRegistry = AppKitMessageRendererRegistry(environment: .init(
            theme: currentTheme,
            mermaidCache: mermaidCache,
            layoutCache: layoutCache,
            outerScrollView: scrollView,
            messageSender: kernel.messageSender
        ))
        tableView.reloadData()
        tableView.layoutSubtreeIfNeeded()
    }

    // MARK: - Snapshot application

    private func apply(snapshot: AppKitMessageListSnapshot) {
        let hadRowsBefore = !dataSource.rows.isEmpty
        let streamingRowID = snapshot.streamingRow?.id
        dataSource.apply(snapshot: snapshot)
        updateOverlays(snapshot: snapshot)

        // Dynamic height: the streaming tail grows with every token. Tell the
        // table the streaming row's height may have changed (measure is cached,
        // so this is cheap) so the viewport follows without a full reload.
        if let streamingRowID,
           let index = dataSource.rows.firstIndex(where: { $0.id == streamingRowID }) {
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: index))
        }

        // First page with real content: pin to the top so the first row is
        // visible and gets drawn. Only follow the bottom when content already
        // existed and the user was already at the bottom (streaming tail).
        guard snapshot.isLoading == false, snapshot.displayRows.last != nil else { return }
        if hadRowsBefore {
            if scrollAnchor.isAtBottom() {
                scrollAnchor.scrollToBottom()
            }
        } else {
            scrollAnchor.scrollToTop()
        }
    }

    private func updateOverlays(snapshot: AppKitMessageListSnapshot) {
        loadingView.isHidden = !snapshot.isLoading
        emptyStateView.isHidden = !(snapshot.isEmpty && !snapshot.isLoading)
    }
}

// MARK: - Appearance Tracking View

/// Root view that notifies the view controller when effective appearance changes.
private final class AppearanceTrackingView: NSView {
    var onAppearanceChanged: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?()
    }
}
