import AppKit
import SwiftUI

public struct AppButton: View {
    @LumiTheme private var theme
    @State private var isHovered = false
    @State private var isSyntheticHovered = false

    public enum Style {
        case primary
        case secondary
        case ghost
        case tonal
    }

    public enum Size {
        case small
        case medium
    }

    struct Metrics: Equatable {
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
    }

    let title: Text
    let systemImage: String?
    let style: Style
    let size: Size
    let fillsWidth: Bool
    let isDisabled: Bool
    let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        style: Style = .secondary,
        size: Size = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.fillsWidth = fillsWidth
        self.isDisabled = false
        self.action = action
    }

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .secondary,
        size: Size = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.fillsWidth = fillsWidth
        self.isDisabled = false
        self.action = action
    }

    private init(
        title: Text,
        systemImage: String?,
        style: Style,
        size: Size,
        fillsWidth: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.fillsWidth = fillsWidth
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                title
            }
            .font(font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
        .background {
            InlinePreviewSyntheticHoverReader { hovering in
                withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                    isSyntheticHovered = hovering && !isDisabled
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering && !isDisabled
            }
        }
    }

    /// Returns a new button with the disabled state set.
    public func disabled(_ isDisabled: Bool) -> AppButton {
        AppButton(
            title: title,
            systemImage: systemImage,
            style: style,
            size: size,
            fillsWidth: fillsWidth,
            isDisabled: isDisabled,
            action: action
        )
    }

    var metrics: Metrics {
        switch size {
        case .small:
            Metrics(horizontalPadding: 10, verticalPadding: 6)
        case .medium:
            Metrics(horizontalPadding: 14, verticalPadding: 10)
        }
    }

    private var font: Font {
        switch size {
        case .small:
            DesignTokens.Typography.caption1
        case .medium:
            DesignTokens.Typography.bodyEmphasized
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            .white
        case .secondary:
            theme.textPrimary
        case .ghost:
            theme.primary
        case .tonal:
            theme.textSecondary
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(isEffectivelyHovered ? theme.primary.opacity(0.85) : theme.primary.opacity(0.5))
            case .secondary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(isEffectivelyHovered ? Color.white.opacity(0.12) : theme.primarySecondary)
            case .ghost:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(isEffectivelyHovered ? theme.primary : Color.clear)
            case .tonal:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(isEffectivelyHovered ? theme.textSecondary.opacity(0.18) : theme.textSecondary.opacity(0.10))
            }
        }
    }

    private var isEffectivelyHovered: Bool {
        (isHovered || isSyntheticHovered) && !isDisabled
    }

    private var border: some View {
        Group {
            switch style {
            case .secondary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(
                        isEffectivelyHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            case .ghost:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(
                        isEffectivelyHovered ? theme.primary.opacity(0.45) : theme.primary.opacity(0.25),
                        lineWidth: 1
                    )
            default:
                EmptyView()
            }
        }
    }
}

private struct InlinePreviewSyntheticHoverReader: NSViewRepresentable {
    let onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> SyntheticHoverView {
        let view = SyntheticHoverView()
        view.onHoverChange = onHoverChange
        return view
    }

    func updateNSView(_ nsView: SyntheticHoverView, context: Context) {
        nsView.onHoverChange = onHoverChange
    }
}

private final class SyntheticHoverView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var isHovering = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyntheticMouse(_:)),
            name: .lumiInlinePreviewSyntheticMouseLocationDidChange,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for SyntheticHoverView.")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    @objc private func handleSyntheticMouse(_ notification: Notification) {
        guard let window, notification.object as? NSWindow === window else {
            updateHover(false)
            return
        }
        guard notification.userInfo?["inside"] as? Bool == true,
              let value = notification.userInfo?["location"] as? NSValue else {
            updateHover(false)
            return
        }

        let point = convert(value.pointValue, from: nil)
        updateHover(bounds.contains(point))
    }

    private func updateHover(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        onHoverChange?(hovering)
    }
}

private extension Notification.Name {
    static let lumiInlinePreviewSyntheticMouseLocationDidChange =
        Notification.Name("com.coffic.lumi.inline-preview.syntheticMouseLocationDidChange")
}

#Preview {
    HStack {
        Spacer()
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                AppButton("Primary", style: .primary) {}
                AppButton("Secondary", style: .secondary) {}
            }
            HStack(spacing: 8) {
                AppButton("Ghost", style: .ghost) {}
                AppButton("Tonal", style: .tonal) {}
            }
            HStack(spacing: 8) {
                AppButton("Small", systemImage: "star", style: .primary, size: .small) {}
                AppButton("With Icon", systemImage: "gearshape", style: .secondary) {}
            }
        }
        Spacer()
    }
    .padding()
    .frame(maxHeight: .infinity)
    .frame(maxWidth: .infinity)
    .background(Color.gray.opacity(0.15))
}
