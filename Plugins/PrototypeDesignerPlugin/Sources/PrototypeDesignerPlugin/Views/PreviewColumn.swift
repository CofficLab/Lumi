import SwiftUI
import WebKit

/// 右侧预览区：在设备画框中渲染当前原型 HTML，支持切换设备、查看源码、复制。
struct PreviewColumn: View {
    @Bindable var viewModel: PrototypeDesignerViewModel
    @State private var reloadToken = 0
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text(viewModel.currentArtifact?.title ?? "预览")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Picker("", selection: $viewModel.selectedDevice) {
                ForEach(PrototypeArtifact.Device.allCases, id: \.self) { device in
                    Label(device.displayName, systemImage: device.systemImage)
                        .labelStyle(.iconOnly)
                        .help(device.displayName)
                        .tag(device)
                }
            }
            .pickerStyle(.segmented)
            .help("切换预览设备")
            .labelsHidden()
            .frame(width: 120)

            Button {
                withAnimation { viewModel.showsCode.toggle() }
            } label: {
                Image(systemName: viewModel.showsCode ? "eye.fill" : "chevron.left.forwardslash.chevron.right")
            }
            .help(viewModel.showsCode ? "查看渲染效果" : "查看 HTML 源码")
            .buttonStyle(.borderless)

            if let html = viewModel.currentArtifact?.html {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(html, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help(copied ? "已复制" : "复制 HTML")
                .buttonStyle(.borderless)

                Button {
                    reloadToken &+= 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新预览")
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if let artifact = viewModel.currentArtifact {
            if viewModel.showsCode {
                codeView(html: artifact.html)
            } else {
                previewCanvas(html: artifact.html)
            }
        } else {
            emptyState
        }
    }

    /// 设备画框 + WKWebView。
    private func previewCanvas(html: String) -> some View {
        GeometryReader { proxy in
            let deviceWidth = viewModel.selectedDevice.previewWidth
            let frameWidth = deviceWidth.flatMap { min($0, max(proxy.size.width - 48, 0)) }
            ScrollView {
                HTMLPreview(html: html, reloadToken: reloadToken)
                    .frame(
                        width: frameWidth,
                        height: max(proxy.size.height - 24, 0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: viewModel.selectedDevice == .desktop ? 6 : 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: viewModel.selectedDevice == .desktop ? 6 : 28, style: .continuous)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                    .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// HTML 源码视图。
    private func codeView(html: String) -> some View {
        ScrollView {
            Text(html)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.dashed.and.paperclip")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("还没有原型")
                .font(.headline)
            Text("在左侧描述你的想法，AI 生成的可交互原型会显示在这里。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WKWebView 桥接

/// 用 WKWebView 渲染单文件 HTML。
///
/// `reloadToken` 变化时强制重新加载，用于"刷新"按钮。
private struct HTMLPreview: NSViewRepresentable {
    let html: String
    let reloadToken: Int

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        load(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        load(into: webView)
    }

    private func load(into webView: WKWebView) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 仅允许同源链接在内部打开，外部链接交给系统浏览器，避免预览区被劫持。
    final class Coordinator: NSObject, WKNavigationDelegate {
        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
