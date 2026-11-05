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

    /// 状态切换（动作条 ↔ 翻译卡片）会改变内容尺寸，通知控制器重新定位。
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

struct TextActionMenuView: View {
    @ObservedObject var model: TextActionMenuModel

    var body: some View {
        content
            .padding(5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: model.state)
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
