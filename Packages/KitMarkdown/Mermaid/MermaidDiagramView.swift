import SwiftUI
import BeautifulMermaid

/// Mermaid 图表渲染视图
/// 基于 beautiful-mermaid-swift 纯 Swift 原生渲染（无 WebView/JS）。
/// 支持 Flowchart、State、Sequence、Class、ER、XY Chart 6 种图表类型。
///
/// ## 用法
///
/// ```swift
/// MermaidDiagramView(source: "graph TD; A-->B; B-->C;")
/// ```
public struct MermaidDiagramView: View {

    /// Mermaid 源码字符串
    private let source: String
    /// 渲染错误
    @State private var renderError: String?
    /// 渲染结果
    @State private var renderedImage: NSImage?
    /// 是否显示扩展 Popover
    @State private var showExpandedPopover = false

    public init(source: String) {
        self.source = source
    }

    public var body: some View {
        Group {
            if let image = renderedImage {
                diagramContent(image: image)
            } else if let error = renderError {
                errorView(error: error)
            } else {
                // 加载中占位
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(height: 80)
            }
        }
        .task(id: source) {
            await renderDiagram()
        }
    }

    // MARK: - Diagram Content with Expand Button

    @ViewBuilder
    private func diagramContent(image: NSImage) -> some View {
        ZStack(alignment: .topTrailing) {
            // 主图内容
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)

            // 右上角扩展按钮
            expandButton
                .padding(8)
        }
    }

    // MARK: - Expand Button

    @ViewBuilder
    private var expandButton: some View {
        Button {
            showExpandedPopover = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(6)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Expand diagram")
        .popover(isPresented: $showExpandedPopover) {
            expandedDiagramView
        }
    }

    // MARK: - Expanded Diagram View (Popover)

    @ViewBuilder
    private var expandedDiagramView: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("Mermaid Diagram")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showExpandedPopover = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))

            Divider()

            // 扩展后的图内容（无高度限制，完整显示）
            ScrollView([.horizontal, .vertical]) {
                if let image = renderedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else if let error = renderError {
                    errorView(error: error)
                        .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .frame(minWidth: 400, minHeight: 300, maxHeight: 600)
        }
        .frame(width: 600, height: 500)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            Text("Mermaid render failed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Text(error)
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    private func renderDiagram() async {
        do {
            let background = NSColor.windowBackgroundColor
            let foreground = NSColor.textColor
            let line = NSColor.secondaryLabelColor
            let surface = NSColor.controlBackgroundColor
            let border = NSColor.separatorColor

            let theme = DiagramTheme(
                background: background,
                foreground: foreground,
                line: line,
                surface: surface,
                border: border
            )

            let image = try await MermaidRenderer.renderImageAsync(
                source: source,
                theme: theme,
                scale: 2.0
            )

            await MainActor.run {
                if let image, let cgImage = image.cgImage {
                    let size = image.size
                    guard size.width > 0, size.height > 0 else {
                        renderedImage = image
                        renderError = nil
                        return
                    }
                    // macOS bitmap path in BeautifulMermaid omits the Y flip that `MermaidLayer.renderImage` applies.
                    let corrected = NSImage(size: size)
                    corrected.lockFocus()
                    defer { corrected.unlockFocus() }
                    if let cg = NSGraphicsContext.current?.cgContext {
                        cg.translateBy(x: 0, y: size.height)
                        cg.scaleBy(x: 1, y: -1)
                        cg.draw(cgImage, in: CGRect(origin: .zero, size: size))
                        renderedImage = corrected
                    } else {
                        renderedImage = image
                    }
                } else {
                    renderedImage = image
                }
                renderError = nil
            }
        } catch {
            await MainActor.run {
                renderError = error.localizedDescription
                renderedImage = nil
            }
        }
    }
}

// MARK: - Preview

#Preview("Simple Flowchart") {
    MermaidDiagramView(source: """
        graph TD
        A[Start] --> B{Decision}
        B -->|Yes| C[Do Something]
        B -->|No| D[End]
        C --> D
        """)
    .padding()
}

#Preview("Complex Diagram") {
    MermaidDiagramView(source: """
        graph TB
        subgraph One
            a1 --> a2
        end
        subgraph Two
            b1 --> b2
        end
        a2 --> b1
        b2 --> c1
        """)
    .padding()
}
