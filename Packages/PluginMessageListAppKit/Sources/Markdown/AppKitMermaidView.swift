import AppKit
import BeautifulMermaid
import Foundation

/// Native Mermaid diagram view.
///
/// Renders asynchronously via `MermaidRenderer.renderImageAsync`, displays the
/// result with an `NSImageView`, caches it, and falls back to a diagnostic
/// block (source + error) on failure. A generation token discards stale async
/// results when the view is reused for a different source.
@MainActor
final class AppKitMermaidView: NSView {
    /// Height reserved while a diagram renders (or for the diagnostic fallback).
    static let placeholderHeight: CGFloat = 140

    private let imageView = NSImageView()
    private let fallbackLabel = NSTextField(wrappingLabelWithString: "")
    private let fallbackScroll = NSScrollView()
    private let fallbackTextView = NSTextView()

    /// Incremented on every configure; async results with a stale generation
    /// are dropped (cancellation without cooperative task support).
    private var generation = 0
    private var lastSourceHash: String?

    var onOpen: ((URL?) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true

        // Fallback diagnostic block (visible only on render failure).
        fallbackScroll.translatesAutoresizingMaskIntoConstraints = false
        fallbackScroll.hasVerticalScroller = true
        fallbackScroll.autohidesScrollers = true
        fallbackTextView.isEditable = false
        fallbackTextView.isSelectable = true
        fallbackTextView.drawsBackground = false
        fallbackScroll.documentView = fallbackTextView

        fallbackLabel.translatesAutoresizingMaskIntoConstraints = false
        fallbackLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        fallbackLabel.textColor = .systemRed
        fallbackLabel.maximumNumberOfLines = 1

        addSubview(imageView)
        addSubview(fallbackLabel)
        addSubview(fallbackScroll)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),

            fallbackLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            fallbackLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            fallbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),

            fallbackScroll.topAnchor.constraint(equalTo: fallbackLabel.bottomAnchor, constant: 4),
            fallbackScroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            fallbackScroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            fallbackScroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        imageView.isHidden = true
        fallbackLabel.isHidden = true
        fallbackScroll.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration

    func configure(
        source: String,
        cache: AppKitMermaidCache,
        theme: AppKitMessageTheme,
        onOpen: ((URL?) -> Void)? = nil
    ) {
        self.onOpen = onOpen
        let sourceHash = AppKitMarkdownParser.fnv1aHash(source)
        if sourceHash == lastSourceHash {
            return // Same diagram already configured.
        }
        lastSourceHash = sourceHash
        generation += 1
        let currentGeneration = generation

        showPlaceholder()

        if let cached = cache.image(for: source) {
            displayImage(cached)
            return
        }

        guard cache.beginRender(for: source) else { return }

        let diagramTheme = DiagramTheme.default
        Task { @MainActor [weak self] in
            let result: Result<BMImage?, Error>
            do {
                result = .success(try await MermaidRenderer.renderImageAsync(source: source, theme: diagramTheme, scale: 2.0))
            } catch {
                result = .failure(error)
            }
            cache.endRender(for: source)

            guard let self, currentGeneration == self.generation else { return }
            switch result {
            case .success(let image):
                if let image {
                    cache.store(image, for: source)
                    self.displayImage(image)
                } else {
                    self.showFallback(source: source, error: "renderer returned no image")
                }
            case .failure(let error):
                self.showFallback(source: source, error: error.localizedDescription)
            }
        }
    }

    // MARK: - Private

    private func showPlaceholder() {
        imageView.image = nil
        imageView.isHidden = true
        fallbackLabel.isHidden = true
        fallbackScroll.isHidden = true
    }

    private func displayImage(_ image: NSImage) {
        imageView.image = image
        imageView.isHidden = false
        fallbackLabel.isHidden = true
        fallbackScroll.isHidden = true
    }

    private func showFallback(source: String, error: String) {
        imageView.isHidden = true
        fallbackLabel.stringValue = LumiPluginLocalization.string("Mermaid render failed", bundle: .module)
        fallbackLabel.isHidden = false
        fallbackTextView.string = "\(source)\n\n错误: \(error)"
        fallbackScroll.isHidden = false
    }
}
