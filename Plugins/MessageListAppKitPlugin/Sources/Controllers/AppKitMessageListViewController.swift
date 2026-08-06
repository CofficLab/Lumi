import AppKit
import LumiKernel

/// Native message-list view controller: an `NSScrollView` + view-based
/// `NSTableView` driven by immutable snapshots from the coordinator.
///
/// The controller owns exactly one coordinator instance and never touches the
/// kernel-wide observation graph. It forwards snapshot deltas to the data
/// source, keeps the scroll position stable on prepend (Task 7 refines this),
/// and manages empty/loading overlays.
@MainActor
final class AppKitMessageListViewController: NSViewController {
    let kernel: LumiKernel

    private var coordinator: AppKitMessageListCoordinator!
    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var dataSource: AppKitMessageListDataSource!
    private var tableDelegate: AppKitMessageTableDelegate!
    private var emptyStateView: AppKitEmptyStateView!
    private var loadingView: AppKitLoadingView!

    init(kernel: LumiKernel) {
        self.kernel = kernel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let root = NSView()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.floatsGroupRows = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("message"))
        column.resizingMask = .autoresizingMask
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

        let dependencies = AppKitMessageListCoordinator.Dependencies(
            conversations: kernel.conversations,
            messageManager: kernel.messageManager,
            agentTurnManager: kernel.agentTurnManager,
            messageStreaming: kernel.messageStreaming,
            messageSender: kernel.messageSender
        )
        coordinator = AppKitMessageListCoordinator(dependencies: dependencies)

        dataSource = AppKitMessageListDataSource()
        dataSource.onLoadEarlier = { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.loadEarlier(isAtBottom: self.isAtBottom) }
        }
        dataSource.attach(tableView: tableView)

        tableDelegate = AppKitMessageTableDelegate()
        tableDelegate.attach(tableView: tableView, dataSource: dataSource)

        let emptyState = AppKitEmptyStateView()
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        emptyState.configure(title: "暂无消息", subtitle: "开始一段新的对话吧")
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

    // MARK: - Snapshot application

    private func apply(snapshot: AppKitMessageListSnapshot) {
        dataSource.apply(snapshot: snapshot)
        updateOverlays(snapshot: snapshot)

        if snapshot.displayRows.last != nil, !snapshot.isLoading, isAtBottom {
            tableView.scrollRowToVisible(max(0, tableView.numberOfRows - 1))
        }
    }

    private func updateOverlays(snapshot: AppKitMessageListSnapshot) {
        loadingView.isHidden = !snapshot.isLoading
        emptyStateView.isHidden = !(snapshot.isEmpty && !snapshot.isLoading)
    }

    /// Bottom-follow heuristic (refined by the scroll anchor in Task 7).
    private var isAtBottom: Bool {
        guard let clipView = scrollView.contentView as NSClipView? else { return true }
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = clipView.bounds.height
        let offsetY = clipView.bounds.origin.y
        return documentHeight - (offsetY + visibleHeight) < 48
    }
}
