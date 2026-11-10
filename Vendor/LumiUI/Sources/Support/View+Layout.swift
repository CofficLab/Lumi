import SwiftUI

// MARK: - Conditional rendering

public extension View {
    /// Renders this view only when `condition` is true.
    ///
    /// Prefer this over wrapping a view in `if` inside a `ViewBuilder` when the
    /// condition reads like a display rule rather than a control-flow branch.
    @ViewBuilder
    func appIf(_ condition: Bool) -> some View {
        if condition {
            self
        } else {
            EmptyView()
        }
    }

    /// Renders this view when `condition` is true, otherwise renders `otherwise`.
    @ViewBuilder
    func appIf<Else: View>(_ condition: Bool, otherwise: () -> Else) -> some View {
        if condition {
            self
        } else {
            otherwise()
        }
    }

    /// Swaps in a transformed variant when `condition` is true, keeping this
    /// view untouched otherwise.
    @ViewBuilder
    func appIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Frame helpers

public extension View {
    /// Expands to fill all space the parent offers, in both axes.
    func appFillAvailableSpace() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Expands vertically only, leaving width determined by the content.
    func appFillAvailableHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }

    /// Centers this view vertically within its parent.
    @ViewBuilder
    func appVStackCenter(
        spacing: CGFloat? = nil,
        alignment: HorizontalAlignment = .center,
        topSpacer: Bool = true,
        bottomSpacer: Bool = true
    ) -> some View {
        VStack(alignment: alignment, spacing: spacing) {
            if topSpacer {
                Spacer()
            }
            self
            if bottomSpacer {
                Spacer()
            }
        }
    }

    /// Centers this view horizontally within its parent.
    @ViewBuilder
    func appHStackCenter(
        spacing: CGFloat? = nil,
        alignment: VerticalAlignment = .center,
        leadingSpacer: Bool = true,
        trailingSpacer: Bool = true
    ) -> some View {
        HStack(alignment: alignment, spacing: spacing) {
            if leadingSpacer {
                Spacer()
            }
            self
            if trailingSpacer {
                Spacer()
            }
        }
    }
}

// MARK: - Shape

public extension View {
    /// Clips this view to a continuously rounded rectangle.
    func appRounded(radius: CGFloat = DesignTokens.Radius.sm, style: RoundedCornerStyle = .continuous) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: style))
    }

    /// Clips to the medium radius token (16pt).
    func appRoundedMedium() -> some View {
        appRounded(radius: DesignTokens.Radius.md)
    }

    /// Clips to the large radius token (24pt).
    func appRoundedLarge() -> some View {
        appRounded(radius: DesignTokens.Radius.lg)
    }
}

// MARK: - Interaction

public extension View {
    /// Wraps this view in a borderless button.
    ///
    /// Use when the label *is* the control, so the whole surface is tappable.
    /// For a labelled button, use `AppButton` instead.
    func appPlainButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(.plain)
    }

    /// Scales this view up while the pointer rests on it, on macOS.
    ///
    /// The animation honors the reduced-motion environment and the app-wide
    /// `LumiMotionPreference`, and is a no-op on platforms without hover.
    func appHoverScale(_ scale: CGFloat, duration: Double = 0.2) -> some View {
        modifier(AppHoverScaleModifier(scale: scale, duration: duration))
    }
}

private struct AppHoverScaleModifier: ViewModifier {
    let scale: CGFloat
    let duration: Double

    @State private var isHovering = false
    @LumiMotionPreferenceReader private var motionPreference

    func body(content: Content) -> some View {
        #if os(macOS) || os(visionOS)
        content
            .scaleEffect(isHovering && motionPreference.allowsMotion ? scale : 1.0)
            .animation(
                LumiMotion.enabled(.easeOut(duration: duration), preference: motionPreference),
                value: isHovering
            )
            .onHover { hovering in
                LumiMotion.animate(LumiMotion.enabled(.easeOut(duration: duration), preference: motionPreference)) {
                    isHovering = hovering
                }
            }
        #else
        content
        #endif
    }
}

// MARK: - Scrolling

public extension View {
    /// Wraps this view in a scroll view.
    ///
    /// - Parameters:
    ///   - axes: Scrollable axes.
    ///   - showsIndicators: Whether the scroll indicators are visible.
    ///   - contentInsets: Optional padding applied to the content, useful when
    ///     the scroll view is inset from its container edges.
    func appScrollView(
        axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        contentInsets: EdgeInsets? = nil
    ) -> some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            if let contentInsets {
                self.padding(contentInsets)
            } else {
                self
            }
        }
    }
}
