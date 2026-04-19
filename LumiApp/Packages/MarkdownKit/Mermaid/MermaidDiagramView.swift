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

    public init(source: String) {
        self.source = source
    }

    public var body: some View {
        Group {
            if let image = renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else if let error = renderError {
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
