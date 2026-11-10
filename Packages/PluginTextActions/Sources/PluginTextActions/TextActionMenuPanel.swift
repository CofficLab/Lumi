import AppKit
import SwiftUI

// MARK: - 浮层状态

/// 浮层的可观察状态。
///
/// 浮层是脱离 Lumi 主窗口的桌面级面板（出现在其他应用上方），因此刻意
/// 不依赖 Lumi 主题系统——与 `ComputerUseTargetOverlayPanel` 的取舍一致，
/// 使用系统材质与系统色。
@MainActor
final class TextActionMenuModel: ObservableObject {
    enum State: Equatable {
        /// 动作条（Copy / Search / Translate）。
        case actions
        /// 复制成功反馈，短暂展示后自动消失。
        case copied
        /// 翻译请求进行中。
        case translating
        /// 翻译完成，展示译文。
        case translated(String)
        /// 翻译失败，展示原因并可重试。
        case failed(String)
    }

    @Published var text: String = ""
    @Published var state: State = .actions {
        didSet { onStateChange?(state) }
    }

    /// 由 `TextActionMenuController` 注入的动作处理器。
    var onPerform: @MainActor (TextAction) -> Void = { _ in }

    /// 状态切换通知（观察用）。
    ///
    /// 浮层尺寸**不由它驱动**：`didSet` 早于 SwiftUI 刷新，此时量尺寸拿到
    /// 的是上一状态的值。尺寸跟随交给 `TextActionMenuHostingView`
    /// 的 intrinsic size 回调。
    var onStateChange: (@MainActor (State) -> Void)?

    func perform(_ action: TextAction) { onPerform(action) }
}

// MARK: - 浮层窗口

/// 划词菜单的桌面级浮层窗口。
///
/// 配置要点（与 Easydict / Xpop 的实现一致）：
/// - `.borderless` + 透明背景——视觉完全交给 SwiftUI 内容；
/// - `.nonactivatingPanel` + `canBecomeKey = false`——**绝不抢焦点**，
///   否则弹出瞬间会打断用户在其他应用里的输入状态；
/// - `hidesOnDeactivate = false`——划词时 Lumi 几乎必然在后台，
///   默认值会让浮层立即被系统隐藏；
/// - `collectionBehavior` 跨 Space、可叠加在全屏应用上。
@MainActor
final class TextActionMenuPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - 浮层内容

/// 承载 SwiftUI 内容的宿主视图。
///
/// 面板尺寸必须等 SwiftUI 真正完成新状态的布局后再取：`model.state` 的
/// `didSet` 早于 SwiftUI 刷新，此刻 `fittingSize` 仍是上一个状态的值。
/// 用它定尺寸会把面板卡在旧高度（例如「翻译中」的 270×46），译文卡片
/// 只剩标题栏、正文被裁成 0 高——正是翻译结果布局崩坏的成因。
///
/// `invalidateIntrinsicContentSize` 是 AppKit 在 SwiftUI 算出新理想尺寸
/// 之后回调的时机，因此把尺寸通知放在这里，并延后一拍读取 `fittingSize`。
@MainActor
final class TextActionMenuHostingView: NSHostingView<TextActionMenuView> {
    /// SwiftUI 的理想尺寸变化后回调，携带新尺寸。
    var onIntrinsicSizeChange: (@MainActor (CGSize) -> Void)?

    private var lastReportedSize: CGSize = .zero
    private var isPendingSizeCheck = false

    required init(rootView: TextActionMenuView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // invalidate 可能发生在布局进行中，此刻读取 fittingSize 会拿到
        // 中间态；延后一拍让 SwiftUI 把新状态的布局落地。
        guard !isPendingSizeCheck else { return }
        isPendingSizeCheck = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPendingSizeCheck = false
            let size = self.fittingSize
            guard size.width > 0, size.height > 0, size != self.lastReportedSize else { return }
            self.lastReportedSize = size
            self.onIntrinsicSizeChange?(size)
        }
    }
}

/// Lumi 品牌标识。
///
/// 图片复用 `LumiApp` 的 App 图标（随包资源分发），保证与 Dock/菜单栏里的
/// Lumi 是同一个符号，而不是另画一套。
/// 源文件: `LumiApp/Assets.xcassets/AppIcon.appiconset/20260206090925-legacy-macos-128x128@2x.png`，
/// App 图标更新时需同步替换 `Resources/LumiBrandMark.png`。
@MainActor
enum LumiBrandMark {
    static let image: NSImage = {
        guard let url = Bundle.module.url(forResource: "LumiBrandMark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Lumi") ?? NSImage()
        }
        return image
    }()
}

struct TextActionMenuView: View {
    @ObservedObject var model: TextActionMenuModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            brandStrip
            content
        }
        .padding(5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: model.state)
    }

    /// Lumi 身份标识。
    ///
    /// 放在所有状态共用的容器里（动作条、复制反馈、翻译中/结果/失败都会出现），
    /// 而不是只加在翻译分支，避免有的入口有标识、有的没有。
    /// 视觉权重刻意压低：9pt 次要色文字 + 13pt App 图标，内容仍是主视觉。
    private var brandStrip: some View {
        HStack(spacing: 4) {
            Image(nsImage: LumiBrandMark.image)
                .resizable()
                .interpolation(.high)
                .frame(width: 13, height: 13)
                .accessibilityHidden(true)
            Text("Lumi")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .padding(.top, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lumi")
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .actions:
            actionsRow
        case .copied:
            copiedRow
        case .translating:
            translatingRow
        case .translated(let translation):
            translationCard(translation)
        case .failed(let message):
            failureCard(message)
        }
    }

    // MARK: 动作条

    private var actionsRow: some View {
        HStack(spacing: 2) {
            ForEach(TextAction.allCases) { action in
                TextActionButton(action: action) {
                    model.perform(action)
                }
            }
        }
    }

    // MARK: 复制反馈

    private var copiedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
            Text(pluginLocalization.string("Copied"))
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: 翻译中

    private var translatingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
            Text(pluginLocalization.string("Translating…"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 260, alignment: .leading)
    }

    // MARK: 翻译结果

    private func translationCard(_ translation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: TextAction.translate.systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(pluginLocalization.string("Translation"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translation, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(pluginLocalization.string("Copy Translation"))
            }

            ScrollView(.vertical) {
                Text(translation)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 180)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 300)
    }

    // MARK: 翻译失败

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                Text(pluginLocalization.string("Translation Failed"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Spacer(minLength: 0)
                Button(pluginLocalization.string("Retry")) {
                    model.perform(.translate)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 300)
    }
}

// MARK: - 动作按钮

/// 单个动作按钮：图标 + 文字，hover 高亮。
///
/// macOS 的 `ButtonStyle` 没有 hover 态，用 `@State` + `.onHover` 自绘。
private struct TextActionButton: View {
    let action: TextAction
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(action.title)
                    .font(.system(size: 9))
            }
            .frame(width: 58, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.1 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
